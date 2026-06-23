//
//  SettingsView.swift
//  Ledger
//
//  Native Form-based settings, skinned with the design system: default income,
//  the adjustable allocation model, recurring, and JSON/CSV export & import.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
#if os(iOS) || os(visionOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("viewedMonthKey") private var viewedKey: String = MonthKey.current

    @Query private var allSettings: [AppSettings]
    @Query(sort: \MonthRecord.key) private var months: [MonthRecord]
    @Query(sort: \RecurringRule.createdAt) private var rules: [RecurringRule]

    @AppStorage("showBucketUsage") private var showBucketUsage = true
    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @AppStorage("hasCompletedOnboarding") private var hasOnboarded = false

    @StateObject private var themeManager = ThemeManager.shared

    @State private var confirmingReset = false

    @EnvironmentObject private var sync: SyncMonitor

    @State private var needsPct = 50
    @State private var savingsPct = 20
    @State private var wantsPct = 30

    // Export / import state
    @State private var showingExporter = false
    @State private var exportKind: ExportKind = .json
    @State private var showingImporter = false
    @State private var showingPasteSheet = false
    @State private var pasteText = ""
    @State private var banner: String?
    @State private var bannerIsError = false

    enum ExportKind { case json, csv }

    private var settings: AppSettings {
        // Use the reactive @Query result to avoid a fetch on every access
        // (e.g. the income field calls this on each keystroke); create only if
        // none exists yet.
        allSettings.first ?? LedgerService.settings(in: context)
    }

    private var draftSplit: BudgetSplit {
        BudgetSplit(needs: Double(needsPct), savings: Double(savingsPct), wants: Double(wantsPct))
    }

    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                incomeSection
                allocationSection
                displaySection
                privacySection
                syncSection
                intelligenceSection
                recurringSection
                dataSection
                resetSection
                aboutSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .readableContentWidth()
            .background(DS.background.ignoresSafeArea())
            .navigationTitle("Settings")
            #if !os(macOS)
            .toolbarTitleDisplayMode(.large)
            #endif
            .overlay(alignment: .bottom) { toast }
            .animation(.spring(duration: 0.3), value: banner)
        }
        .tint(DS.gold)
        .sensoryFeedback(trigger: banner) { _, newValue in
            guard newValue != nil else { return nil }
            return bannerIsError ? .error : .success
        }
        .onAppear(perform: loadDrafts)
        .fileExporter(isPresented: $showingExporter,
                      document: ExportDocument(data: exportKind == .json ? jsonData()
                                                                          : Data(csvText().utf8)),
                      contentType: exportKind == .json ? .json : .commaSeparatedText,
                      defaultFilename: exportKind == .json ? "ledger-export"
                                                           : "ledger-transactions") { result in
            if case .failure(let error) = result {
                flash("Export failed: \(error.localizedDescription)", isError: true)
            } else {
                flash("Exported \(exportKind == .json ? "JSON" : "CSV")")
            }
        }
        .fileImporter(isPresented: $showingImporter,
                      allowedContentTypes: [.json, .commaSeparatedText, .plainText],
                      allowsMultipleSelection: false) { handleImport($0) }
        .sheet(isPresented: $showingPasteSheet) { pasteSheet }
        .confirmationDialog("Reset all data?",
                            isPresented: $confirmingReset,
                            titleVisibility: .visible) {
            Button("Delete Everything", role: .destructive) { performReset() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This permanently deletes all months, transactions, recurring rules, and settings. With iCloud on, it clears every device. This can't be undone.")
        }
    }

    // MARK: Appearance (themes)

    private var appearanceSection: some View {
        Section {
            ForEach(AppTheme.allCases) { theme in
                Button {
                    themeManager.setTheme(theme)
                } label: {
                    themeRow(theme)
                }
                .buttonStyle(.plain)
                .hoverHighlight()
            }
        } header: {
            Text("Appearance")
        } footer: {
            Text("Themes restyle the whole app. Each one follows your Light / Dark setting automatically.")
        }
        .listRowBackground(DS.surface)
    }

    private func themeRow(_ theme: AppTheme) -> some View {
        let selected = theme == themeManager.theme
        return HStack(spacing: Spacing.md) {
            themeSwatch(theme.palette)
            VStack(alignment: .leading, spacing: 2) {
                Text(theme.displayName)
                    .font(.body)
                    .foregroundStyle(DS.text)
                Text(theme.subtitle)
                    .font(.caption)
                    .foregroundStyle(DS.textMuted)
            }
            Spacer()
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(selected ? DS.accent : DS.textMuted.opacity(0.4))
        }
        .contentShape(Rectangle())
    }

    /// A tiny preview of a theme's own palette (independent of the active theme),
    /// so each row shows the look you'd get — in the current Light/Dark mode.
    private func themeSwatch(_ p: ThemePalette) -> some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(p.background)
            .frame(width: 48, height: 36)
            .overlay {
                HStack(spacing: 4) {
                    Capsule().fill(p.needs)
                    Capsule().fill(p.savings)
                    Capsule().fill(p.wants)
                    Capsule().fill(p.accent)
                }
                .frame(width: 30, height: 15)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(p.hairline, lineWidth: 1)
            }
    }

    // MARK: Default income

    private var incomeSection: some View {
        Section {
            LabeledContent {
                MoneyField(amount: Binding(get: { settings.defaultIncome },
                                           set: { settings.defaultIncome = $0 }))
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .font(Typography.mono(.body, weight: .medium))
                    .foregroundStyle(DS.text)
            } label: {
                Text("Monthly default")
            }
        } header: {
            Text("Default Income")
        } footer: {
            Text("Carried forward to each new month.")
        }
        .listRowBackground(DS.surface)
    }

    // MARK: Allocation model

    private var allocationSection: some View {
        Section {
            HStack(spacing: Spacing.sm) {
                Button("50 / 30 / 20") { setPreset(50, 30, 20) }
                Button("50 / 20 / 30") { setPreset(50, 20, 30) }
            }
            .buttonStyle(.bordered)
            .tint(DS.gold)
            .frame(maxWidth: .infinity)

            splitStepper("Needs", value: $needsPct, color: DS.needs)
            splitStepper("Savings", value: $savingsPct, color: DS.savings)
            splitStepper("Wants", value: $wantsPct, color: DS.wants)

            LabeledContent {
                Text("\(Int(draftSplit.total))%")
                    .font(Typography.mono(.body, weight: .semibold))
                    .foregroundStyle(draftSplit.isValid ? DS.savings : DS.needs)
            } label: {
                Text(draftSplit.isValid ? "Total" : "Total — must equal 100%")
                    .foregroundStyle(draftSplit.isValid ? DS.text : DS.needs)
            }

            Button("Save as Default") {
                settings.defaultSplit = draftSplit
                flash("Default split saved")
            }
            .disabled(!draftSplit.isValid)

            Button("Apply to \(MonthKey.displayName(viewedKey))") {
                if let month = months.first(where: { $0.key == viewedKey }), !month.isClosed {
                    month.needsPct = draftSplit.needs
                    month.savingsPct = draftSplit.savings
                    month.wantsPct = draftSplit.wants
                    flash("Applied to \(MonthKey.displayName(viewedKey))")
                } else {
                    flash("Current month is closed or missing", isError: true)
                }
            }
            .disabled(!draftSplit.isValid)
        } header: {
            Text("Allocation Model")
        } footer: {
            Text("Set your default split for new months. Past months keep the split they were created with.")
        }
        .listRowBackground(DS.surface)
    }

    private func splitStepper(_ label: String, value: Binding<Int>, color: Color) -> some View {
        Stepper(value: value, in: 0...100, step: 1) {
            HStack(spacing: Spacing.sm) {
                Circle().fill(color).frame(width: 9, height: 9)
                Text(label).foregroundStyle(DS.text)
                Spacer()
                Text("\(value.wrappedValue)%")
                    .font(Typography.mono(.body, weight: .medium))
                    .foregroundStyle(DS.textMuted)
            }
        }
    }

    private func setPreset(_ n: Int, _ s: Int, _ w: Int) {
        needsPct = n; savingsPct = s; wantsPct = w
    }

    // MARK: Display

    private var displaySection: some View {
        Section {
            Toggle(isOn: $showBucketUsage) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show bucket usage %")
                    Text("e.g. \"84% used\" on each bucket")
                        .font(.caption)
                        .foregroundStyle(DS.textMuted)
                }
            }
            .tint(DS.savings)
        } header: {
            Text("Display")
        }
        .listRowBackground(DS.surface)
    }

    // MARK: iCloud sync status

    private var syncSection: some View {
        Section {
            LabeledContent {
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(StoreStatus.usingCloudKit ? DS.savings : DS.needs)
                        .frame(width: 9, height: 9)
                    Text(StoreStatus.usingCloudKit ? "On" : "Local only")
                        .font(Typography.mono(.body, weight: .medium))
                        .foregroundStyle(StoreStatus.usingCloudKit ? DS.savings : DS.needs)
                }
            } label: {
                Text("iCloud Sync")
            }

            if StoreStatus.usingCloudKit {
                syncPhaseRow("Setup", phase: sync.setup)
                syncPhaseRow("Last received", phase: sync.imports)
                syncPhaseRow("Last sent", phase: sync.exports)
            }
        } header: {
            Text("iCloud")
        } footer: {
            syncFooter
        }
        .listRowBackground(DS.surface)
    }

    /// One status line for a sync phase: in-progress, last success time, or a failure.
    private func syncPhaseRow(_ label: String, phase: SyncMonitor.Phase) -> some View {
        LabeledContent {
            Group {
                if phase.inProgress {
                    Text("Syncing…").foregroundStyle(DS.textMuted)
                } else if phase.error != nil {
                    Text("Failed").foregroundStyle(DS.needs)
                } else if let end = phase.lastEnd {
                    Text(relativeTime(end)).foregroundStyle(DS.text)
                } else {
                    Text("—").foregroundStyle(DS.textMuted)
                }
            }
            .font(Typography.mono(.footnote, weight: .medium))
        } label: {
            Text(label)
        }
    }

    @ViewBuilder
    private var syncFooter: some View {
        if !StoreStatus.usingCloudKit {
            if let err = StoreStatus.fallbackError {
                Text("Couldn't start iCloud sync, so data is stored only on this device. Details: \(err)")
            } else {
                Text("iCloud sync is turned off in this build; data is stored only on this device.")
            }
        } else if let err = sync.imports.error {
            Text("Receive (import) error: \(err)").foregroundStyle(DS.needs)
        } else if let err = sync.setup.error {
            Text("Setup error: \(err)").foregroundStyle(DS.needs)
        } else if let err = sync.exports.error {
            Text("Send (export) error: \(err)").foregroundStyle(DS.needs)
        } else {
            Text("Your data syncs across your devices via iCloud. \"Received\" is the last time changes came down from another device; \"Sent\" is the last time this device's changes went up.")
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }

    // MARK: Privacy (biometric lock)

    private var privacySection: some View {
        Section {
            Toggle(isOn: $appLockEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Require Face ID")
                    Text(BiometricAuth.isAvailable
                         ? "Lock Ledger when you leave the app."
                         : "Set a device passcode or Face ID to enable this.")
                        .font(.caption)
                        .foregroundStyle(DS.textMuted)
                }
            }
            .tint(DS.savings)
            .disabled(!BiometricAuth.isAvailable)
            .onChange(of: appLockEnabled) { _, enabled in
                // Trigger the iOS Face ID consent/confirmation right when the
                // switch is turned on; revert if the user cancels or it fails.
                guard enabled else { return }
                Task {
                    let ok = await BiometricAuth.authenticate(reason: "Confirm Face ID to lock Ledger")
                    if !ok { await MainActor.run { appLockEnabled = false } }
                }
            }
        } header: {
            Text("Privacy")
        }
        .listRowBackground(DS.surface)
    }

    // MARK: Intelligence (AI command bar)

    private var intelligenceSection: some View {
        Section {
            LabeledContent {
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(IntelligenceService.isAvailable ? DS.savings : DS.textMuted)
                        .frame(width: 9, height: 9)
                    Text(IntelligenceService.isAvailable ? "Available" : "Unavailable")
                        .font(Typography.mono(.body, weight: .medium))
                        .foregroundStyle(IntelligenceService.isAvailable ? DS.savings : DS.textMuted)
                }
            } label: {
                Text("AI Command Bar")
            }

            if IntelligenceService.isAvailable {
                Button("Reset Learned Categories", role: .destructive) {
                    CategoryMemory.reset()
                    flash("Cleared learned categories")
                }
                .disabled(CategoryMemory.count == 0)
            }
        } header: {
            Text("Intelligence")
        } footer: {
            Text(IntelligenceService.statusMessage + (CategoryMemory.count > 0
                 ? " The command bar remembers the categories you pick for each merchant."
                 : ""))
        }
        .listRowBackground(DS.surface)
    }

    // MARK: Recurring

    private var recurringSection: some View {
        Section {
            NavigationLink {
                RecurringView()
            } label: {
                Label("Recurring Transactions", systemImage: "arrow.triangle.2.circlepath")
            }
        } header: {
            Text("Recurring")
        }
        .listRowBackground(DS.surface)
    }

    // MARK: Data (export / import)

    private var dataSection: some View {
        Section {
            Button { exportKind = .json; showingExporter = true } label: {
                Label("Export JSON", systemImage: "square.and.arrow.up")
            }
            Button { exportKind = .csv; showingExporter = true } label: {
                Label("Export CSV", systemImage: "tablecells")
            }
            Button { copyJSON() } label: {
                Label("Copy JSON to Clipboard", systemImage: "doc.on.doc")
            }
            Button { showingImporter = true } label: {
                Label("Import from File", systemImage: "square.and.arrow.down")
            }
            Button { pasteText = ""; showingPasteSheet = true } label: {
                Label("Paste JSON / CSV", systemImage: "doc.on.clipboard")
            }
        } header: {
            Text("Backup & Sync")
        } footer: {
            Text("Export a backup or move data between devices. JSON includes everything; CSV is transactions only.")
        }
        .listRowBackground(DS.surface)
    }

    // MARK: Reset all data

    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                confirmingReset = true
            } label: {
                Label("Reset All Data…", systemImage: "trash")
            }
        } header: {
            Text("Danger Zone")
        } footer: {
            Text("Permanently deletes every month, transaction, recurring rule, and your settings. With iCloud on, this clears your data on all your devices. Export a backup first if you might want it back.")
        }
        .listRowBackground(DS.surface)
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("App", value: "Ledger")
            LabeledContent("Rule", value: "50 / 30 / 20")
        } header: {
            Text("About")
        } footer: {
            Text("A 50/30/20 budget tracker for iPhone, iPad, Mac and Vision Pro.")
        }
        .listRowBackground(DS.surface)
    }

    // MARK: Toast

    @ViewBuilder
    private var toast: some View {
        if let banner {
            Text(banner)
                .font(Typography.mono(.footnote, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .background((bannerIsError ? DS.needs : DS.savings), in: Capsule())
                .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                .padding(.bottom, Spacing.xl)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: Paste sheet

    private var pasteSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Paste exported JSON or transactions CSV below.")
                    .font(.subheadline)
                    .foregroundStyle(DS.textMuted)
                TextEditor(text: $pasteText)
                    .font(Typography.mono(.footnote))
                    .foregroundStyle(DS.text)
                    .scrollContentBackground(.hidden)
                    .padding(Spacing.sm)
                    .background(DS.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                    .frame(minHeight: 240)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(DS.background.ignoresSafeArea())
            .navigationTitle("Paste Data")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingPasteSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        importText(pasteText)
                        showingPasteSheet = false
                    }
                }
            }
        }
        .tint(DS.gold)
    }

    // MARK: Helpers

    private func loadDrafts() {
        let s = settings
        needsPct = Int(s.defaultNeedsPct)
        savingsPct = Int(s.defaultSavingsPct)
        wantsPct = Int(s.defaultWantsPct)
    }

    private func archive() -> ExportData {
        LedgerArchive.makeExport(settings: allSettings.first, months: months, rules: rules)
    }

    private func jsonData() -> Data {
        (try? LedgerArchive.encodeJSON(archive())) ?? Data()
    }

    private func csvText() -> String {
        LedgerArchive.encodeCSV(archive())
    }

    private func copyJSON() {
        let text = String(data: jsonData(), encoding: .utf8) ?? ""
        Clipboard.copy(text)
        flash("JSON copied")
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            flash("Import cancelled: \(error.localizedDescription)", isError: true)
        case .success(let urls):
            guard let url = urls.first else { return }
            let needsStop = url.startAccessingSecurityScopedResource()
            defer { if needsStop { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                guard let text = String(data: data, encoding: .utf8) else {
                    flash("File isn't UTF-8 text", isError: true); return
                }
                importText(text)
            } catch {
                flash("Couldn't read file: \(error.localizedDescription)", isError: true)
            }
        }
    }

    private func importText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { flash("Nothing to import", isError: true); return }

        // JSON if it looks like a JSON object/array; otherwise treat as CSV.
        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
            do {
                // Auto-detects this app's format or the original web app's backup.
                let archive = try LedgerArchive.decodeAny(Data(trimmed.utf8),
                                                          defaultSplit: settings.defaultSplit)
                LedgerService.importArchive(archive, in: context)
                let txns = archive.months.reduce(0) { $0 + $1.transactions.count }
                flash("Imported \(archive.months.count) month(s), \(txns) transaction(s)")
            } catch {
                flash("JSON error — \(decodeMessage(error))", isError: true)
            }
        } else {
            let buckets = LedgerArchive.decodeCSV(trimmed)
            if buckets.isEmpty {
                flash("Couldn't parse — expected JSON, or CSV with header: month,date,description,category,amount", isError: true)
            } else {
                LedgerService.importCSVTransactions(buckets, in: context)
                let count = buckets.values.reduce(0) { $0 + $1.count }
                flash("Imported \(count) transaction(s)")
            }
        }
    }

    /// Turn a DecodingError into something human-readable.
    private func decodeMessage(_ error: Error) -> String {
        guard let decodingError = error as? DecodingError else {
            return error.localizedDescription
        }
        switch decodingError {
        case .keyNotFound(let key, _):
            return "missing field \"\(key.stringValue)\""
        case .typeMismatch(_, let ctx):
            return "wrong type at \(path(ctx)) — \(ctx.debugDescription)"
        case .valueNotFound(_, let ctx):
            return "null at \(path(ctx))"
        case .dataCorrupted(let ctx):
            return ctx.debugDescription
        @unknown default:
            return decodingError.localizedDescription
        }
    }

    private func path(_ ctx: DecodingError.Context) -> String {
        let p = ctx.codingPath.map(\.stringValue).joined(separator: ".")
        return p.isEmpty ? "top level" : p
    }

    private func performReset() {
        LedgerService.resetAllData(in: context)
        CategoryMemory.reset()
        BudgetSnapshotStore.update(from: [])
        viewedKey = MonthKey.current
        hasOnboarded = false          // re-show onboarding for a clean start
        loadDrafts()                  // reset the allocation steppers to defaults
        flash("All data reset")
    }

    private func flash(_ message: String, isError: Bool = false) {
        banner = message
        bannerIsError = isError
        let shown = message
        DispatchQueue.main.asyncAfter(deadline: .now() + (isError ? 6 : 2.5)) {
            if banner == shown { banner = nil }
        }
    }
}

// MARK: - Cross-platform clipboard

enum Clipboard {
    static func copy(_ text: String) {
        #if os(iOS) || os(visionOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}
