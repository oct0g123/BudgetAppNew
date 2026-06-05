//
//  SettingsView.swift
//  Ledger
//
//  Default income, the adjustable allocation model (presets or fully custom),
//  and JSON/CSV export & import.
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
    @State private var needsDraft = "50"
    @State private var savingsDraft = "20"
    @State private var wantsDraft = "30"

    // Export / import state
    @State private var showingJSONExporter = false
    @State private var showingCSVExporter = false
    @State private var showingImporter = false
    @State private var showingPasteSheet = false
    @State private var pasteText = ""
    @State private var banner: String?
    @State private var bannerIsError = false

    private var settings: AppSettings {
        LedgerService.settings(in: context)
    }

    private var draftSplit: BudgetSplit {
        BudgetSplit(needs: Double(needsDraft) ?? 0,
                    savings: Double(savingsDraft) ?? 0,
                    wants: Double(wantsDraft) ?? 0)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if let banner {
                            Text(banner)
                                .font(.mono(12))
                                .foregroundStyle(bannerIsError ? Palette.needs : Palette.savings)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(Palette.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10)
                                    .stroke(bannerIsError ? Palette.needs.opacity(0.6) : .clear, lineWidth: 1))
                        }
                        defaultIncomeCard
                        allocationCard
                        recurringCard
                        dataCard
                        aboutCard
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
        }
        .tint(Palette.gold)
        .onAppear(perform: loadDrafts)
        .fileExporter(isPresented: $showingJSONExporter,
                      document: JSONDocument(data: jsonData()),
                      contentType: .json,
                      defaultFilename: "ledger-export") { _ in }
        .fileExporter(isPresented: $showingCSVExporter,
                      document: CSVDocument(text: csvText()),
                      contentType: .commaSeparatedText,
                      defaultFilename: "ledger-transactions") { _ in }
        .fileImporter(isPresented: $showingImporter,
                      allowedContentTypes: [.json, .commaSeparatedText, .plainText],
                      allowsMultipleSelection: false) { handleImport($0) }
        .sheet(isPresented: $showingPasteSheet) { pasteSheet }
    }

    // MARK: Default income

    private var defaultIncomeCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel("Default Income")
                Text("Carried forward to each new month.")
                    .font(.system(.caption))
                    .foregroundStyle(Palette.textMuted)
                HStack {
                    TextField("0", text: $incomeDraft)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .font(.mono(22, weight: .medium))
                        .foregroundStyle(Palette.text)
                    Button("Save") {
                        settings.defaultIncome = Double(incomeDraft) ?? 0
                        flash("Default income saved")
                    }
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Palette.gold)
                }
                .padding(12)
                .background(Palette.surfaceHigh)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: Allocation model

    private var allocationCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel("Allocation Model")
                Text("Set your default split for new months. Past months keep the split they were created with.")
                    .font(.system(.caption))
                    .foregroundStyle(Palette.textMuted)

                // Labels are in Needs / Savings / Wants order.
                HStack(spacing: 8) {
                    presetButton("50 / 30 / 20", split: BudgetSplit(needs: 50, savings: 30, wants: 20))
                    presetButton("50 / 20 / 30", split: BudgetSplit(needs: 50, savings: 20, wants: 30))
                }

                VStack(spacing: 10) {
                    splitRow("Needs", text: $needsDraft, color: Palette.needs)
                    splitRow("Savings", text: $savingsDraft, color: Palette.savings)
                    splitRow("Wants", text: $wantsDraft, color: Palette.wants)
                }

                HStack {
                    let total = draftSplit.total
                    Text("Total: \(Int(total))%")
                        .font(.mono(13, weight: .medium))
                        .foregroundStyle(draftSplit.isValid ? Palette.savings : Palette.needs)
                    if !draftSplit.isValid {
                        Text("must equal 100%")
                            .font(.mono(11))
                            .foregroundStyle(Palette.needs)
                    }
                    Spacer()
                }

                Button {
                    settings.defaultSplit = draftSplit
                    flash("Default split saved")
                } label: {
                    primaryLabel("Save as Default")
                }
                .buttonStyle(.plain)
                .disabled(!draftSplit.isValid)
                .opacity(draftSplit.isValid ? 1 : 0.5)

                Button {
                    if let month = months.first(where: { $0.key == viewedKey }), !month.isClosed {
                        let s = draftSplit
                        month.needsPct = s.needs
                        month.savingsPct = s.savings
                        month.wantsPct = s.wants
                        flash("Applied to \(MonthKey.displayName(viewedKey))")
                    } else {
                        flash("Current month is closed or missing")
                    }
                } label: {
                    secondaryLabel("Apply to Current Month")
                }
                .buttonStyle(.plain)
                .disabled(!draftSplit.isValid)
                .opacity(draftSplit.isValid ? 1 : 0.5)
            }
        }
    }

    private func presetButton(_ title: String, split: BudgetSplit) -> some View {
        Button {
            needsDraft = String(Int(split.needs))
            savingsDraft = String(Int(split.savings))
            wantsDraft = String(Int(split.wants))
        } label: {
            Text(title)
                .font(.mono(12, weight: .medium))
                .foregroundStyle(draftSplit == split ? Palette.background : Palette.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(draftSplit == split ? Palette.gold : Palette.surfaceHigh)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func splitRow(_ label: String, text: Binding<String>, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.system(.body))
                .foregroundStyle(Palette.text)
            Spacer()
            TextField("0", text: text)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
                .multilineTextAlignment(.trailing)
                .font(.mono(16, weight: .medium))
                .foregroundStyle(Palette.text)
                .frame(width: 56)
            Text("%")
                .font(.mono(14))
                .foregroundStyle(Palette.textMuted)
        }
        .padding(12)
        .background(Palette.surfaceHigh)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Recurring

    private var recurringCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel("Recurring")
                NavigationLink {
                    RecurringView()
                } label: {
                    rowLabel("Recurring Transactions", system: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Data (export / import)

    private var dataCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel("Backup & Sync")
                Text("Your data already syncs across devices via iCloud. Use these for manual backups or moving data in and out.")
                    .font(.system(.caption))
                    .foregroundStyle(Palette.textMuted)

                Button { showingJSONExporter = true } label: {
                    rowLabel("Export JSON", system: "square.and.arrow.up")
                }.buttonStyle(.plain)

                Button { showingCSVExporter = true } label: {
                    rowLabel("Export CSV", system: "tablecells")
                }.buttonStyle(.plain)

                Button { copyJSON() } label: {
                    rowLabel("Copy JSON to Clipboard", system: "doc.on.doc")
                }.buttonStyle(.plain)

                Divider().background(Palette.hairline)

                Button { showingImporter = true } label: {
                    rowLabel("Import from File", system: "square.and.arrow.down")
                }.buttonStyle(.plain)

                Button { pasteText = ""; showingPasteSheet = true } label: {
                    rowLabel("Paste JSON / CSV", system: "doc.on.clipboard")
                }.buttonStyle(.plain)
            }
        }
    }

    private var aboutCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel("About")
                Text("Ledger — a 50/30/20 budget tracker.")
                    .font(.system(.subheadline))
                    .foregroundStyle(Palette.text)
                Text("Built for iPhone, iPad, Mac and Vision Pro. Data syncs privately through your iCloud account.")
                    .font(.system(.caption))
                    .foregroundStyle(Palette.textMuted)
            }
        }
    }

    // MARK: Reusable labels

    private func primaryLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(.body, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Palette.gold)
            .foregroundStyle(Palette.background)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func secondaryLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(.subheadline, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(Palette.surfaceHigh)
            .foregroundStyle(Palette.text)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.hairline, lineWidth: 1))
    }

    private func rowLabel(_ title: String, system: String) -> some View {
        HStack {
            Image(systemName: system).foregroundStyle(Palette.gold).frame(width: 24)
            Text(title).font(.system(.body)).foregroundStyle(Palette.text)
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(Palette.textMuted)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    // MARK: Paste sheet

    private var pasteSheet: some View {
        NavigationStack {
            ZStack {
                Palette.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 12) {
                    Text("Paste exported JSON or transactions CSV below.")
                        .font(.system(.subheadline))
                        .foregroundStyle(Palette.textMuted)
                    TextEditor(text: $pasteText)
                        .font(.mono(12))
                        .foregroundStyle(Palette.text)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Palette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .frame(minHeight: 240)
                }
                .padding(20)
            }
            .navigationTitle("Paste Data")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingPasteSheet = false }
                        .foregroundStyle(Palette.textMuted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        importText(pasteText)
                        showingPasteSheet = false
                    }
                    .foregroundStyle(Palette.gold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Helpers

    private func loadDrafts() {
        let s = settings
        incomeDraft = String(format: "%.0f", s.defaultIncome)
        needsDraft = String(Int(s.defaultNeedsPct))
        savingsDraft = String(Int(s.defaultSavingsPct))
        wantsDraft = String(Int(s.defaultWantsPct))
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
