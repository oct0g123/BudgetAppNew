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
            RecurringRule.self
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
            .preferredColorScheme(AppColorScheme(rawValue: appColorScheme)?.colorScheme)
        }
        .modelContainer(AppModelContainer.shared)
        #if os(macOS)
        .defaultSize(width: 920, height: 680)
        #endif
        #if os(visionOS)
        .defaultSize(width: 720, height: 900)
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
