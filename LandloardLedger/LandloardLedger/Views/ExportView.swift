import SwiftUI
import SwiftData

struct ExportView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Property.name) private var properties: [Property]

    @State private var selectedYear  = Calendar.current.component(.year, from: Date())
    @State private var pdfData:  Data?
    @State private var showShare     = false
    @State private var isGenerating  = false

    private var availableYears: [Int] {
        let current = Calendar.current.component(.year, from: Date())
        return Array((current - 4)...current).reversed()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {

                Spacer()

                // Icon
                Image(systemName: "doc.richtext")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)

                // Controls
                VStack(spacing: 20) {
                    Text("Generate Tax Report")
                        .font(.title2.bold())

                    Text("Creates a Schedule E summary PDF for all properties — ready to hand to your accountant.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    // Year picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tax Year")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Picker("Tax Year", selection: $selectedYear) {
                            ForEach(availableYears, id: \.self) { year in
                                Text(String(year)).tag(year)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Summary of what will be included
                    if !properties.isEmpty {
                        reportPreview
                    }

                    // Generate button
                    Button {
                        generatePDF()
                    } label: {
                        if isGenerating {
                            HStack(spacing: 8) {
                                ProgressView().scaleEffect(0.8)
                                Text("Generating…")
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            Label("Generate \(selectedYear) Report", systemImage: "doc.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isGenerating || properties.isEmpty)

                    if properties.isEmpty {
                        Text("Add at least one property in Settings first.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .navigationTitle("Export")
            .sheet(isPresented: $showShare) {
                if let data = pdfData {
                    ShareSheetView(data: data, filename: "LandlordLedger_\(selectedYear).pdf")
                }
            }
        }
    }

    // MARK: - Report preview

    private var reportPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What's included")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            ForEach(properties) { property in
                let count = transactionCount(for: property, year: selectedYear)
                HStack {
                    Text(property.name)
                        .font(.caption)
                    Spacer()
                    Text("\(count) transaction\(count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Generate

    private func generatePDF() {
        isGenerating = true
        DispatchQueue.global(qos: .userInitiated).async {
            let data = PDFExporter.buildPDF(properties: properties, year: selectedYear)
            DispatchQueue.main.async {
                pdfData      = data
                isGenerating = false
                showShare    = true
            }
        }
    }

    // MARK: - Helpers

    private func transactionCount(for property: Property, year: Int) -> Int {
        property.approvedTransactions.filter {
            Calendar.current.component(.year, from: $0.date) == year
        }.count
    }
}

// MARK: - Share sheet wrapper

struct ShareSheetView: UIViewControllerRepresentable {

    let data: Data
    let filename: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: url)

        let controller = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
