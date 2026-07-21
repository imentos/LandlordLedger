import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportView: View {

    var showsDoneButton = false

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var properties: [Property]
    @Query private var tenants: [Tenant]
    @Query private var matchingRules: [MatchingRule]

    @State private var viewModel    = ImportViewModel()
    @State private var showFilePicker = false
    @State private var pastedCSVText = ""

    var body: some View {
        NavigationStack {
            Group {
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
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsDoneButton {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
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
        }
    }

    // MARK: - Sub-views

    private var idleView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Copy CSV text on your computer, then tap Paste here to import it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Paste CSV")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if let count = previewTransactionCount {
                            Text("\(count) detected")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    TextEditor(text: $pastedCSVText)
                        .font(.system(.footnote, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .frame(maxWidth: .infinity, minHeight: 180)
                        .padding(8)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))

                    PasteButton(payloadType: String.self) { strings in
                        guard let csvText = strings.first else { return }
                        pastedCSVText = csvText
                        importPastedText()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(properties.isEmpty)
                }

                if properties.isEmpty {
                    Text("Add at least one property in Settings first.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
                Text("Open the Transactions tab to review \(summary.needsReview) transaction\(summary.needsReview == 1 ? "" : "s").")
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
        let csvText = pastedCSVText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !csvText.isEmpty else { return }

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
