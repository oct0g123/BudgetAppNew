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
#if os(iOS) || os(visionOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

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
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }
}
#elseif os(macOS)
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.registerForRemoteNotifications()
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

/// Set to `true` only when building with a paid developer account that has the
/// iCloud + CloudKit capability enabled.
private let enableCloudKitSync = true

@main
struct LedgerApp: App {

    #if os(iOS) || os(visionOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #elseif os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    let container: ModelContainer

    init() {
        Typography.registerBundledFonts()

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
            container = try ModelContainer(for: schema, configurations: configuration)
            if enableCloudKitSync {
                StoreStatus.usingCloudKit = true
                storeLog.notice("🟢 Ledger: CloudKit store ACTIVE (cloud sync enabled).")
            } else {
                storeLog.notice("⚪️ Ledger: local store (CloudKit sync disabled in code).")
            }
        } catch {
            StoreStatus.fallbackError = String(describing: error)
            // If the configured store can't be created (e.g. CloudKit requested
            // without a valid entitlement, or not signed in to iCloud), fall
            // back to a plain local store so the app still runs.
            storeLog.error("🔴 Ledger: CloudKit store FAILED, falling back to LOCAL. Error: \(String(describing: error), privacy: .public)")
            let localConfig = ModelConfiguration(schema: schema,
                                                 isStoredInMemoryOnly: false,
                                                 cloudKitDatabase: .none)
            do {
                container = try ModelContainer(for: schema, configurations: localConfig)
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(DS.gold)
        }
        .modelContainer(container)
        #if os(macOS)
        .defaultSize(width: 920, height: 680)
        #endif
    }
}
