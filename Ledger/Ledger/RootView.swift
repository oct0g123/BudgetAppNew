//
//  RootView.swift
//  Ledger
//

import SwiftUI
import SwiftData

struct RootView: View {
    var body: some View {
        TabView {
            BudgetView()
                .tabItem { Label("Budget", systemImage: "chart.pie") }

            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .background(Palette.background)
    }
}

#Preview {
    RootView()
        .modelContainer(for: [MonthRecord.self, Transaction.self, AppSettings.self],
                        inMemory: true)
        .preferredColorScheme(.dark)
}
