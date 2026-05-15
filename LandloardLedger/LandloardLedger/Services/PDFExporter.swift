import UIKit
import SwiftData

// MARK: - Per-property summary used during PDF generation

struct PropertyPDFSummary {
    let propertyName: String
    let address: String
    let transactions: [Transaction]

    var incomeRows: [(category: String, total: Decimal)] {
        grouped(isIncome: true)
    }
    var expenseRows: [(category: String, total: Decimal)] {
        grouped(isIncome: false)
    }
    var totalIncome: Decimal  { transactions.filter { $0.amount >= 0 }.reduce(0) { $0 + $1.amount } }
    var totalExpenses: Decimal { transactions.filter { $0.amount < 0 }.reduce(0) { $0 + abs($1.amount) } }
    var netIncome: Decimal    { totalIncome - totalExpenses }

    private func grouped(isIncome: Bool) -> [(category: String, total: Decimal)] {
        let rows = transactions.filter { isIncome ? $0.amount >= 0 : $0.amount < 0 }
        let dict = Dictionary(grouping: rows, by: \.category)
        return dict.map { cat, txs in
            let total = txs.reduce(Decimal(0)) { $0 + abs($1.amount) }
            return (category: cat, total: total)
        }.sorted { $0.category < $1.category }
    }
}

// MARK: - PDF Exporter

struct PDFExporter {

    // MARK: - Public entry point

    /// Build a PDF document for all properties for the given year.
    /// Returns the PDF data.
    static func buildPDF(properties: [Property], year: Int) -> Data {
        let pageWidth:  CGFloat = 612   // US Letter
        let pageHeight: CGFloat = 792
        let margin:     CGFloat = 48

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        return renderer.pdfData { ctx in
            let summaries: [PropertyPDFSummary] = properties.map { property in
                let txs = property.approvedTransactions.filter { tx in
                    Calendar.current.component(.year, from: tx.date) == year
                }
                return PropertyPDFSummary(
                    propertyName: property.name,
                    address: property.address,
                    transactions: txs
                )
            }

            // Cover page
            ctx.beginPage()
            drawCoverPage(ctx: ctx,
                          year: year,
                          summaries: summaries,
                          pageWidth: pageWidth,
                          margin: margin)

            // One page (or more) per property
            for summary in summaries {
                ctx.beginPage()
                drawPropertyPage(ctx: ctx,
                                 summary: summary,
                                 year: year,
                                 pageWidth: pageWidth,
                                 pageHeight: pageHeight,
                                 margin: margin)
            }
        }
    }

    // MARK: - Cover page

    private static func drawCoverPage(
        ctx: UIGraphicsPDFRendererContext,
        year: Int,
        summaries: [PropertyPDFSummary],
        pageWidth: CGFloat,
        margin: CGFloat
    ) {
        var y: CGFloat = margin

        // Title
        let title = "Schedule E Rental Income & Expenses"
        draw(title,
             at: CGPoint(x: margin, y: y),
             width: pageWidth - margin * 2,
             font: .boldSystemFont(ofSize: 20),
             color: .black)
        y += 30

        // Year
        draw("Tax Year \(year)",
             at: CGPoint(x: margin, y: y),
             width: pageWidth - margin * 2,
             font: .systemFont(ofSize: 14),
             color: .darkGray)
        y += 28

        drawHLine(at: y, margin: margin, pageWidth: pageWidth)
        y += 20

        // Portfolio summary table
        draw("Portfolio Summary",
             at: CGPoint(x: margin, y: y),
             width: pageWidth - margin * 2,
             font: .boldSystemFont(ofSize: 13),
             color: .black)
        y += 22

        let colW = (pageWidth - margin * 2) / 4
        drawTableHeader(["Property", "Income", "Expenses", "Net Income"],
                        y: y, margin: margin, colW: colW, pageWidth: pageWidth)
        y += 20

        for s in summaries {
            let cols = [s.propertyName,
                        currencyStr(s.totalIncome),
                        currencyStr(s.totalExpenses),
                        currencyStr(s.netIncome)]
            drawTableRow(cols, y: y, margin: margin, colW: colW)
            y += 18
        }

        // Grand totals
        drawHLine(at: y, margin: margin, pageWidth: pageWidth)
        y += 8

        let totalIncome   = summaries.reduce(Decimal(0)) { $0 + $1.totalIncome }
        let totalExpenses = summaries.reduce(Decimal(0)) { $0 + $1.totalExpenses }
        let totalNet      = totalIncome - totalExpenses
        let totRow = ["TOTAL", currencyStr(totalIncome), currencyStr(totalExpenses), currencyStr(totalNet)]
        drawTableRow(totRow, y: y, margin: margin, colW: colW, bold: true)

        // Footer
        draw("Generated by LandlordLedger on \(Date().formatted(date: .abbreviated, time: .shortened))",
             at: CGPoint(x: margin, y: 792 - margin - 16),
             width: pageWidth - margin * 2,
             font: .systemFont(ofSize: 9),
             color: .gray)
    }

    // MARK: - Property detail page

    private static func drawPropertyPage(
        ctx: UIGraphicsPDFRendererContext,
        summary: PropertyPDFSummary,
        year: Int,
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        margin: CGFloat
    ) {
        var y: CGFloat = margin

        // Property header
        draw(summary.propertyName,
             at: CGPoint(x: margin, y: y),
             width: pageWidth - margin * 2,
             font: .boldSystemFont(ofSize: 17),
             color: .black)
        y += 24

        if !summary.address.isEmpty {
            draw(summary.address,
                 at: CGPoint(x: margin, y: y),
                 width: pageWidth - margin * 2,
                 font: .systemFont(ofSize: 11),
                 color: .darkGray)
            y += 18
        }

        draw("Tax Year \(year)",
             at: CGPoint(x: margin, y: y),
             width: pageWidth - margin * 2,
             font: .systemFont(ofSize: 11),
             color: .darkGray)
        y += 22

        drawHLine(at: y, margin: margin, pageWidth: pageWidth)
        y += 14

        let colW3 = (pageWidth - margin * 2) / 3

        // Income section
        if !summary.incomeRows.isEmpty {
            y = drawSection(title: "INCOME",
                            rows: summary.incomeRows,
                            total: summary.totalIncome,
                            totalLabel: "Total Income",
                            y: y,
                            margin: margin,
                            colW: colW3,
                            pageWidth: pageWidth,
                            pageHeight: pageHeight,
                            ctx: ctx)
            y += 16
        }

        // Expense section
        if !summary.expenseRows.isEmpty {
            y = drawSection(title: "EXPENSES",
                            rows: summary.expenseRows,
                            total: summary.totalExpenses,
                            totalLabel: "Total Expenses",
                            y: y,
                            margin: margin,
                            colW: colW3,
                            pageWidth: pageWidth,
                            pageHeight: pageHeight,
                            ctx: ctx)
            y += 16
        }

        // Net income
        drawHLine(at: y, margin: margin, pageWidth: pageWidth)
        y += 10

        let netCols = ["NET INCOME (LOSS)", "", currencyStr(summary.netIncome)]
        drawTableRow(netCols, y: y, margin: margin, colW: colW3, bold: true,
                     thirdColor: summary.netIncome >= 0 ? UIColor.systemGreen : UIColor.systemRed)

        // Footer
        draw("Generated by LandlordLedger on \(Date().formatted(date: .abbreviated, time: .shortened))",
             at: CGPoint(x: margin, y: pageHeight - margin - 16),
             width: pageWidth - margin * 2,
             font: .systemFont(ofSize: 9),
             color: .gray)
    }

    // MARK: - Section helper

    @discardableResult
    private static func drawSection(
        title: String,
        rows: [(category: String, total: Decimal)],
        total: Decimal,
        totalLabel: String,
        y startY: CGFloat,
        margin: CGFloat,
        colW: CGFloat,
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        ctx: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        var y = startY

        // Section heading
        draw(title,
             at: CGPoint(x: margin, y: y),
             width: pageWidth - margin * 2,
             font: .boldSystemFont(ofSize: 11),
             color: .darkGray)
        y += 16

        drawTableHeader(["Category", "Description", "Amount"],
                        y: y, margin: margin, colW: colW, pageWidth: pageWidth)
        y += 18

        for row in rows {
            // Page break guard
            if y > pageHeight - 80 {
                ctx.beginPage()
                y = 48
            }
            let cols = [row.category, "", currencyStr(row.total)]
            drawTableRow(cols, y: y, margin: margin, colW: colW)
            y += 16
        }

        // Subtotal
        drawHLine(at: y, margin: margin, pageWidth: pageWidth)
        y += 6
        let subtotCols = [totalLabel, "", currencyStr(total)]
        drawTableRow(subtotCols, y: y, margin: margin, colW: colW, bold: true)
        y += 18

        return y
    }

    // MARK: - Drawing primitives

    private static func draw(
        _ text: String,
        at point: CGPoint,
        width: CGFloat,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment = .left
    ) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        let rect = CGRect(x: point.x, y: point.y, width: width, height: 200)
        text.draw(in: rect, withAttributes: attrs)
    }

    private static func drawHLine(at y: CGFloat, margin: CGFloat, pageWidth: CGFloat) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: y))
        path.addLine(to: CGPoint(x: pageWidth - margin, y: y))
        UIColor.lightGray.setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }

    private static func drawTableHeader(
        _ cols: [String],
        y: CGFloat,
        margin: CGFloat,
        colW: CGFloat,
        pageWidth: CGFloat
    ) {
        for (i, col) in cols.enumerated() {
            let x = margin + CGFloat(i) * colW
            draw(col,
                 at: CGPoint(x: x, y: y),
                 width: colW - 4,
                 font: .boldSystemFont(ofSize: 10),
                 color: .darkGray,
                 alignment: i == cols.count - 1 ? .right : .left)
        }
    }

    private static func drawTableRow(
        _ cols: [String],
        y: CGFloat,
        margin: CGFloat,
        colW: CGFloat,
        bold: Bool = false,
        thirdColor: UIColor = .black
    ) {
        let font: UIFont = bold ? .boldSystemFont(ofSize: 10) : .systemFont(ofSize: 10)
        for (i, col) in cols.enumerated() {
            let x = margin + CGFloat(i) * colW
            let color: UIColor = (i == cols.count - 1) ? thirdColor : .black
            draw(col,
                 at: CGPoint(x: x, y: y),
                 width: colW - 4,
                 font: font,
                 color: color,
                 alignment: i == cols.count - 1 ? .right : .left)
        }
    }

    // MARK: - Number formatting

    private static func currencyStr(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
    }
}
