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

/// Set to `true` only when building with a paid developer account that has the
/// iCloud + CloudKit capability enabled.
private let enableCloudKitSync = false

@main
struct LedgerApp: App {

    let container: ModelContainer

    init() {
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
        } catch {
            // If the configured store can't be created (e.g. CloudKit requested
            // without a valid entitlement, or not signed in to iCloud), fall
            // back to a plain local store so the app still runs.
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
                .tint(Palette.gold)
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
        #if os(macOS)
        .defaultSize(width: 920, height: 680)
        #endif
    }
}
