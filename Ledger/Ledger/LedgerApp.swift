//
//  LedgerApp.swift
//  Ledger
//
//  App entry point and SwiftData ModelContainer setup.
//
//  iCloud sync (CloudKit) requires a PAID Apple Developer Program membership —
//  a free Apple ID can't provision the iCloud capability, so the app is set up
//  to run with a LOCAL store by default. When you have a paid account and want
//  cross-device sync:
//    1. Flip `enableCloudKitSync` below to `true`.
//    2. In the target's Signing & Capabilities, add the iCloud capability with
//       CloudKit and create/select a container (e.g. iCloud.com.you.Ledger).
//    3. Restore the iCloud keys in Ledger.entitlements (see the commented
//       block there).
//  Until then, use Settings → Backup & Sync (JSON/CSV export & import) to move
//  data between devices manually.
//

import SwiftUI
import SwiftData
import os
import CoreData
import Combine
#if os(iOS) || os(visionOS)
import UIKit
#elseif os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif
import LocalAuthentication
import UserNotifications

private let storeLog = Logger(subsystem: "com.anthonystacy.Ledger", category: "store")

// MARK: - Remote notification registration
//
// SwiftData/CloudKit pulls remote changes down through its import pipeline,
// which is driven by CloudKit subscription *push* notifications. In a SwiftUI
// `App`, nothing calls `registerForRemoteNotifications()` for us, so the
// registration "gives up", the subscription never finishes setting up, and
// changes made on other devices never sync down (while local changes still
// export fine). Registering on launch via an app-delegate adaptor fixes import.

#if os(iOS) || os(visionOS)
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        application.registerForRemoteNotifications()
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Show budget-alert banners even while the app is in the foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
#elseif os(macOS)
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.registerForRemoteNotifications()
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
#endif

/// Observable, read-anywhere snapshot of how the data store came up. Set once
/// during app init, before any UI appears. Lets Settings show the user whether
/// iCloud sync is actually live or the app fell back to a local store.
enum StoreStatus {
    /// `true` when the CloudKit-backed store initialized successfully.
    static var usingCloudKit = false
    /// Non-nil when the CloudKit store failed and we fell back to local.
    static var fallbackError: String?
}

// MARK: - Sync monitor
//
// SwiftData drives iCloud through NSPersistentCloudKitContainer, which posts an
// `eventChangedNotification` for every setup / import / export operation —
// including whether it succeeded and the underlying error. Observing those lets
// us show real sync status (and surface failures) instead of just "store opened".

final class SyncMonitor: ObservableObject {

    /// Shared instance so non-UI code (e.g. pull-to-refresh) can READ sync
    /// state without SwiftUI observation — observing this object from a big
    /// view rebuilds it on every CloudKit event (the old Settings-hang bug).
    static let shared = SyncMonitor()

    struct Phase {
        var inProgress = false
        var lastEnd: Date?
        var succeeded = true
        var error: String?
    }

    @Published private(set) var setup = Phase()
    @Published private(set) var imports = Phase()
    @Published private(set) var exports = Phase()

    private var observer: NSObjectProtocol?

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard
                let self,
                let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event
            else { return }
            self.apply(event)
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    private func apply(_ event: NSPersistentCloudKitContainer.Event) {
        var phase = Phase()
        phase.inProgress = event.endDate == nil
        phase.lastEnd = event.endDate
        phase.succeeded = event.succeeded
        phase.error = event.error?.localizedDescription
        switch event.type {
        case .setup:  setup = phase
        case .import: imports = phase
        case .export: exports = phase
        @unknown default: break
        }
    }
}

/// Set to `true` only when building with a paid developer account that has the
/// iCloud + CloudKit capability enabled.
private let enableCloudKitSync = true

// MARK: - Shared model container

/// Single source of truth for the SwiftData store, shared by the app *and* the
/// App Intents — so Siri/Shortcuts writes land in the same (CloudKit-synced)
/// store the UI uses. Falls back to a local store if the cloud store can't init.
enum AppModelContainer {
    static let shared: ModelContainer = {
        let schema = Schema([
            MonthRecord.self,
            Transaction.self,
            AppSettings.self,
            RecurringRule.self,
            PaymentCard.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: enableCloudKitSync ? .automatic : .none
        )
        do {
            let container = try ModelContainer(for: schema, configurations: configuration)
            if enableCloudKitSync {
                StoreStatus.usingCloudKit = true
                storeLog.notice("🟢 Ledger: CloudKit store ACTIVE (cloud sync enabled).")
            } else {
                storeLog.notice("⚪️ Ledger: local store (CloudKit sync disabled in code).")
            }
            return container
        } catch {
            StoreStatus.fallbackError = String(describing: error)
            storeLog.error("🔴 Ledger: CloudKit store FAILED, falling back to LOCAL. Error: \(String(describing: error), privacy: .public)")
            let localConfig = ModelConfiguration(schema: schema,
                                                 isStoredInMemoryOnly: false,
                                                 cloudKitDatabase: .none)
            if let local = try? ModelContainer(for: schema, configurations: localConfig) {
                return local
            }
            // Last resort: an in-memory store so the app still launches instead
            // of crashing (data won't persist, but it won't hard-fail).
            storeLog.error("🔴 Ledger: local store also failed; using an in-memory store.")
            let memConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            if let mem = try? ModelContainer(for: schema, configurations: memConfig) {
                return mem
            }
            fatalError("Could not create any ModelContainer")
        }
    }()
}

// MARK: - Mac menu bar
//
// macOS only. Menu commands live OUTSIDE the view tree, so they reach the
// window through focused scene values rather than a shared object. That choice
// is deliberate: a singleton would be shared across scenes, and `WindowGroup`
// opens multiple windows on iPadOS (Stage Manager / Split View) and visionOS —
// two windows would then fight over one `selectedTab`. `.focusedSceneValue` is
// per-scene, so only the frontmost window responds and `AppNavigator` stays
// exactly as it is on every other platform.

#if os(macOS)
struct NewTransactionKey: FocusedValueKey { typealias Value = () -> Void }
struct SelectTabKey: FocusedValueKey { typealias Value = (AppTab) -> Void }

extension FocusedValues {
    var newTransaction: NewTransactionKey.Value? {
        get { self[NewTransactionKey.self] }
        set { self[NewTransactionKey.self] = newValue }
    }
    var selectTab: SelectTabKey.Value? {
        get { self[SelectTabKey.self] }
        set { self[SelectTabKey.self] = newValue }
    }
}

/// Export straight from the menu bar.
///
/// It reads the shared container directly rather than routing through
/// SettingsView: Settings is its own SCENE on Mac now (⌘,), so a command in the
/// main window has no path to its export state. Same archive builder the
/// in-app export uses, so the files are identical.
@MainActor
enum LedgerExport {
    enum Kind { case json, csv }

    static func save(_ kind: Kind) {
        let context = AppModelContainer.shared.mainContext
        let archive = LedgerArchive.makeExport(
            settings: (try? context.fetch(FetchDescriptor<AppSettings>()))?.first,
            months: LedgerService.allMonths(in: context),
            rules: LedgerService.allRecurringRules(in: context),
            cards: LedgerService.allCards(in: context))

        let data: Data
        switch kind {
        case .json:
            guard let encoded = try? LedgerArchive.encodeJSON(archive) else {
                alert("Couldn't prepare the export.")
                return
            }
            data = encoded
        case .csv:
            data = Data(LedgerArchive.encodeCSV(archive).utf8)
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [kind == .json ? .json : .commaSeparatedText]
        panel.nameFieldStringValue = kind == .json ? "ledger-export" : "ledger-transactions"
        guard panel.runModal() == .OK, let url = panel.url else { return }   // cancelled
        do {
            try data.write(to: url)
        } catch {
            alert("Couldn't save the export: \(error.localizedDescription)")
        }
    }

    private static func alert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}

/// File ▸ New Transaction and export, plus View ▸ section and month navigation.
struct LedgerCommands: Commands {
    /// The viewed month is `@AppStorage`, so month commands need no view state
    /// at all — they read and write the same key the Budget screen does.
    @AppStorage("viewedMonthKey") private var viewedKey: String = MonthKey.current
    @FocusedValue(\.newTransaction) private var newTransaction
    @FocusedValue(\.selectTab) private var selectTab

    var body: some Commands {
        // `replacing:` — a WindowGroup automatically binds File ▸ New Window
        // to ⌘N, so an `after:` item asking for ⌘N is a DUPLICATE binding and
        // the system's wins (which is why ⌘N did nothing while ⌘1–3 worked).
        // Replacing the group takes ⌘N and drops New Window, which is the right
        // trade here: in a budgeting app "New" means a transaction, and a
        // second window of the same synced data earns very little.
        CommandGroup(replacing: .newItem) {
            Button("New Transaction") { newTransaction?() }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(newTransaction == nil)
            Divider()
            Button("Export JSON…") { LedgerExport.save(.json) }
                .keyboardShortcut("e", modifiers: .command)
            Button("Export CSV…") { LedgerExport.save(.csv) }
                .keyboardShortcut("e", modifiers: [.command, .shift])
        }

        CommandGroup(after: .sidebar) {
            Divider()
            Button("Budget")   { selectTab?(.budget) }
                .keyboardShortcut("1", modifiers: .command)
            Button("Insights") { selectTab?(.insights) }
                .keyboardShortcut("2", modifiers: .command)
            Button("History")  { selectTab?(.history) }
                .keyboardShortcut("3", modifiers: .command)
            Divider()
            Button("Previous Month") { viewedKey = MonthKey.offset(viewedKey, by: -1) }
                .keyboardShortcut("[", modifiers: .command)
            Button("Next Month") { viewedKey = MonthKey.offset(viewedKey, by: 1) }
                .keyboardShortcut("]", modifiers: .command)
            Button("Current Month") { viewedKey = MonthKey.current }
                .keyboardShortcut("t", modifiers: [.command, .shift])
                .disabled(viewedKey == MonthKey.current)
        }
    }
}
#endif

@main
struct LedgerApp: App {

    #if os(iOS) || os(visionOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #elseif os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    @StateObject private var syncMonitor = SyncMonitor.shared
    @StateObject private var themeManager = ThemeManager.shared
    @AppStorage("appColorScheme") private var appColorScheme = AppColorScheme.system.rawValue

    init() {
        Typography.registerBundledFonts()
        _ = AppModelContainer.shared   // build the store + set StoreStatus at launch
    }

    var body: some Scene {
        WindowGroup {
            LockGate {
                RootView()
                    .tint(DS.accent)
                    .environmentObject(syncMonitor)
                    .environmentObject(themeManager)
            }
            // visionOS pins to dark: the glass surfaces need light-content
            // text — the Light palette's near-black text disappears against
            // the material (the theme picker still drives palette/accent).
            #if os(visionOS)
            .preferredColorScheme(.dark)
            #else
            .preferredColorScheme(AppColorScheme(rawValue: appColorScheme)?.colorScheme)
            #endif
        }
        .modelContainer(AppModelContainer.shared)
        #if os(macOS)
        .defaultSize(width: 920, height: 680)
        .windowResizability(.contentMinSize)
        .commands { LedgerCommands() }
        #endif
        #if os(visionOS)
        .defaultSize(width: 720, height: 900)
        #endif

        // Mac keeps preferences where Mac users look for them: ⌘, in its own
        // window, not a fourth item in the sidebar. This is a SEPARATE scene,
        // so it needs its own model container and its own environment objects
        // — SyncStatusSection reads SyncMonitor via @EnvironmentObject and
        // would trap without it.
        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(syncMonitor)
                .environmentObject(themeManager)
                .tint(DS.accent)
                .preferredColorScheme(AppColorScheme(rawValue: appColorScheme)?.colorScheme)
        }
        .modelContainer(AppModelContainer.shared)
        #endif
    }
}

// MARK: - Biometric app lock

enum BiometricAuth {
    /// Whether the device can authenticate (Face ID / Touch ID / Optic ID / passcode).
    static var isAvailable: Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    /// The device's actual biometry, for UI copy — "Face ID" on iPhone,
    /// "Touch ID" on Macs, "Optic ID" on Vision Pro. Falls back to "Passcode"
    /// when no biometry is enrolled (the policy still allows the passcode).
    static var kindName: String {
        switch biometryType {
        case .faceID:  return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default:       return "Passcode"
        }
    }

    /// Matching SF Symbol for `kindName`.
    static var kindSymbol: String {
        switch biometryType {
        case .faceID:  return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        default:       return "lock"
        }
    }

    private static var biometryType: LABiometryType {
        let ctx = LAContext()
        var error: NSError?
        // biometryType is only populated after canEvaluatePolicy runs.
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        return ctx.biometryType
    }

    static func authenticate(reason: String = "Unlock Ledger") async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}

/// Optional Face ID gate around the app. When enabled, the UI is covered
/// whenever the app isn't active (so the App Switcher can't reveal data) and
/// requires authentication after returning from the background.
struct LockGate<Content: View>: View {
    @AppStorage("appLockEnabled") private var lockEnabled = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var unlocked = false
    @State private var authenticating = false
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    private var showCover: Bool { lockEnabled && (!unlocked || scenePhase != .active) }
    private var showUnlock: Bool { lockEnabled && !unlocked && scenePhase == .active }

    var body: some View {
        ZStack {
            content()
            if showCover { cover }
        }
        .task {
            if !lockEnabled { unlocked = true }
            else if !unlocked { tryUnlock() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background, lockEnabled { unlocked = false }
            if phase == .active, lockEnabled, !unlocked { tryUnlock() }
        }
        .onChange(of: lockEnabled) { _, enabled in
            if !enabled { unlocked = true }
        }
    }

    private var cover: some View {
        ZStack {
            DS.background.ignoresSafeArea()
            VStack(spacing: Spacing.lg) {
                Image(systemName: "lock.fill")
                    .font(.largeTitle)
                    .foregroundStyle(DS.gold)
                Text("Ledger is locked")
                    .font(Typography.serif(.title3))
                    .foregroundStyle(DS.text)
                if showUnlock {
                    Button { tryUnlock() } label: {
                        Label("Unlock", systemImage: BiometricAuth.kindSymbol)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DS.gold)
                    .disabled(authenticating)
                }
            }
        }
    }

    private func tryUnlock() {
        guard !authenticating else { return }
        authenticating = true
        Task {
            let ok = await BiometricAuth.authenticate()
            await MainActor.run {
                unlocked = ok
                authenticating = false
            }
        }
    }
}
