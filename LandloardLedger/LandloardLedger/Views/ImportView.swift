import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

struct ImportView: View {

    @Environment(\.modelContext) private var modelContext
    @Query private var properties: [Property]
    @Query private var tenants: [Tenant]
    @Query private var matchingRules: [MatchingRule]

    @State private var viewModel    = ImportViewModel()
    @State private var showFilePicker = false
    @State private var showPasteSheet = false
    @State private var showManualTransactionSheet = false
    @State private var pastedCSVText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {

                Spacer()

                // Icon
                Image(systemName: "square.and.arrow.down.on.square")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)

                // State-dependent content
                switch viewModel.state {

                case .idle:
                    idleView

                case .parsing:
                    progressView(message: "Reading file…")

                case .categorizing(let progress):
                    progressView(message: progress)

                case .saving:
                    progressView(message: "Saving transactions…")

                case .done(let summary):
                    summaryView(summary)

                case .error(let msg):
                    errorView(msg)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Import")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showManualTransactionSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(properties.isEmpty)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                handleFilePick(result)
            }
            .sheet(isPresented: $showPasteSheet) {
                pasteCSVSheet
            }
            .sheet(isPresented: $showManualTransactionSheet) {
                ManualTransactionView()
            }
        }
    }

    // MARK: - Sub-views

    private var idleView: some View {
        VStack(spacing: 16) {
            Text("Import this week's transactions")
                .font(.headline)
            Text("Export the last 7 days from Chase as CSV, then import it here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showFilePicker = true
            } label: {
                Label("Choose Chase CSV", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(properties.isEmpty)

            Button {
                showPasteSheet = true
            } label: {
                Label("Paste CSV Text", systemImage: "doc.on.clipboard")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(properties.isEmpty)

            if properties.isEmpty {
                Text("Add at least one property in Settings first.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var pasteCSVSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextEditor(text: $pastedCSVText)
                    .font(.system(.footnote, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .frame(minHeight: 260)
                    .padding(8)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

                HStack {
                    Button {
                        pastedCSVText = UIPasteboard.general.string ?? ""
                    } label: {
                        Label("Paste Clipboard", systemImage: "clipboard")
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    if let count = previewTransactionCount {
                        Text("\(count) transaction\(count == 1 ? "" : "s") detected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    importPastedText()
                } label: {
                    Label("Import Pasted CSV", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(pastedCSVText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .navigationTitle("Paste CSV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showPasteSheet = false }
                }
            }
        }
    }

    private func progressView(message: String) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func summaryView(_ summary: ImportSummary) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("Import complete")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 8) {
                summaryRow("Transactions found",   value: summary.totalParsed)
                summaryRow("Already imported",     value: summary.duplicatesSkipped)
                summaryRow("Auto-approved by rules", value: summary.autoApproved)
                summaryRow("Needs your review",    value: summary.needsReview, highlight: summary.needsReview > 0)
            }
            .padding()
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

            if summary.needsReview > 0 {
                Text("Open the Inbox tab to review \(summary.needsReview) transaction\(summary.needsReview == 1 ? "" : "s").")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Import another file") {
                viewModel.state = .idle
            }
            .buttonStyle(.bordered)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)

            Text("Import failed")
                .font(.title3.bold())

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Try again") {
                viewModel.state = .idle
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func summaryRow(_ label: String, value: Int, highlight: Bool = false) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(value)")
                .bold()
                .foregroundStyle(highlight ? .orange : .primary)
        }
    }

    // MARK: - File picker handler

    private func handleFilePick(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                await viewModel.importCSV(
                    url: url,
                    properties: properties,
                    tenants: tenants,
                    matchingRules: matchingRules,
                    modelContext: modelContext
                )
            }
        case .failure(let error):
            viewModel.state = .error(error.localizedDescription)
        }
    }

    private var previewTransactionCount: Int? {
        guard !pastedCSVText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return try? CSVParser.parse(csvText: pastedCSVText).count
    }

    private func importPastedText() {
        let csvText = pastedCSVText
        showPasteSheet = false
        Task {
            try? await viewModel.importCSVText(
                csvText,
                properties: properties,
                tenants: tenants,
                matchingRules: matchingRules,
                modelContext: modelContext
            )
        }
    }
}
