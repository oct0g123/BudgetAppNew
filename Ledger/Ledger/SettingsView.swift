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

    @State private var incomeDraft = ""
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
        LedgerService.settings(in: context)
    }

    private var draftSplit: BudgetSplit {
        BudgetSplit(needs: Double(needsPct), savings: Double(savingsPct), wants: Double(wantsPct))
    }

    var body: some View {
        NavigationStack {
            Form {
                incomeSection
                allocationSection
                recurringSection
                dataSection
                aboutSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(DS.background.ignoresSafeArea())
            .navigationTitle("Settings")
            .toolbarTitleDisplayMode(.large)
            .overlay(alignment: .bottom) { toast }
            .animation(.spring(duration: 0.3), value: banner)
        }
        .tint(DS.gold)
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
    }

    // MARK: Default income

    private var incomeSection: some View {
        Section {
            LabeledContent {
                TextField("0", text: $incomeDraft)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .multilineTextAlignment(.trailing)
                    .font(Typography.mono(.body, weight: .medium))
                    .foregroundStyle(DS.text)
                    .onChange(of: incomeDraft) { _, newValue in
                        settings.defaultIncome = Double(newValue) ?? 0
                    }
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
        incomeDraft = String(format: "%.0f", s.defaultIncome)
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
