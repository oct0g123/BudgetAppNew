//
//  LedgerApp.swift
//  Ledger
//
//  App entry point. Sets up a SwiftData ModelContainer backed by CloudKit so
//  data syncs across the user's devices automatically.
//

import SwiftUI
import SwiftData

@main
struct LedgerApp: App {

    /// Shared container. `.automatic` CloudKit database uses the iCloud
    /// container named in Ledger.entitlements (default private database).
    let container: ModelContainer

    init() {
        let schema = Schema([
            MonthRecord.self,
            Transaction.self,
            AppSettings.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        do {
            container = try ModelContainer(for: schema, configurations: configuration)
        } catch {
            // If the CloudKit-backed store can't be created (e.g. not signed in
            // to iCloud, or entitlement missing in a dev build), fall back to a
            // local-only store so the app still runs.
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
