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

            InsightsView()
                .tabItem { Label("Insights", systemImage: "chart.bar.xaxis") }

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
        .modelContainer(for: [MonthRecord.self, Transaction.self, AppSettings.self, RecurringRule.self],
                        inMemory: true)
        .preferredColorScheme(.dark)
}
