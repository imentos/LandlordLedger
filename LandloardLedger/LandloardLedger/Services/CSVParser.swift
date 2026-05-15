import Foundation

// MARK: - Result type

struct ParsedTransaction {
    let date:        Date
    let description: String
    let amount:      Decimal   // positive = income, negative = expense
    let type:        String
}

// MARK: - Errors

enum CSVParseError: LocalizedError {
    case emptyFile
    case missingDateColumn
    case missingDescriptionColumn
    case missingAmountColumn
    case noValidRows

    var errorDescription: String? {
        switch self {
        case .emptyFile:             return "The file is empty."
        case .missingDateColumn:     return "Could not find a date column. Expected 'Posting Date', 'Transaction Date', 'Trans. Date', or 'Date'."
        case .missingDescriptionColumn: return "Could not find a description column. Expected 'Description' or 'Merchant Name or Transaction Description'."
        case .missingAmountColumn:   return "Could not find an 'Amount' column."
        case .noValidRows:           return "The file contained no readable transactions."
        }
    }
}

// MARK: - Parser

struct CSVParser {

    // MARK: - Public

    /// Parse a Chase CSV export (checking or credit card format).
    /// Returns rows with positive amounts for income, negative for expenses.
    static func parse(csvText: String) throws -> [ParsedTransaction] {

        let lines = csvText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { throw CSVParseError.emptyFile }

        // Some Chase exports have a leading summary line before the header.
        // Header is the first line that contains "Amount" (case-insensitive).
        guard let headerIndex = lines.firstIndex(where: {
            $0.lowercased().contains("amount")
        }) else {
            throw CSVParseError.missingAmountColumn
        }

        let headerFields = splitCSVLine(lines[headerIndex])
        let dataLines    = Array(lines.dropFirst(headerIndex + 1))

        // Resolve column indices — Chase uses slightly different names for
        // checking vs credit card exports.
        let dateIndex = columnIndex(
            in: headerFields,
            candidates: ["posting date", "transaction date", "trans. date", "date"]
        )
        let descIndex = columnIndex(
            in: headerFields,
            candidates: ["description", "merchant name or transaction description"]
        )
        let amtIndex  = columnIndex(
            in: headerFields,
            candidates: ["amount"]
        )
        let typeIndex = columnIndex(
            in: headerFields,
            candidates: ["type"]
        )

        guard let di = dateIndex  else { throw CSVParseError.missingDateColumn }
        guard let xi = descIndex  else { throw CSVParseError.missingDescriptionColumn }
        guard let ai = amtIndex   else { throw CSVParseError.missingAmountColumn }

        var results: [ParsedTransaction] = []

        for line in dataLines {
            let fields = splitCSVLine(line)
            guard fields.count > max(di, xi, ai) else { continue }

            let rawDate   = fields[di].trimmingCharacters(in: .whitespaces)
            let rawDesc   = fields[xi].trimmingCharacters(in: .whitespaces)
            let rawAmount = fields[ai]
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: ",", with: "") // "1,800.00" → "1800.00"
            let rawType = typeIndex.flatMap { fields.count > $0 ? fields[$0].trimmingCharacters(in: .whitespaces) : nil } ?? ""

            guard !rawDate.isEmpty, !rawDesc.isEmpty else { continue }

            guard let date   = parseDate(rawDate)      else { continue }
            guard let amount = Decimal(string: rawAmount) else { continue }

            results.append(ParsedTransaction(
                date:        date,
                description: rawDesc,
                amount:      amount,
                type:        rawType
            ))
        }

        guard !results.isEmpty else { throw CSVParseError.noValidRows }

        // Sort oldest → newest so import order is chronological
        return results.sorted { $0.date < $1.date }
    }

    // MARK: - Private helpers

    /// Find the first column index whose lowercased header matches any candidate string.
    private static func columnIndex(in headers: [String], candidates: [String]) -> Int? {
        for (i, header) in headers.enumerated() {
            if candidates.contains(header.lowercased().trimmingCharacters(in: .whitespaces)) {
                return i
            }
        }
        return nil
    }

    /// RFC 4180-compliant CSV field splitter.
    /// Handles quoted fields (may contain commas or newlines), and strips outer quotes.
    static func splitCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        var i = line.startIndex
        while i < line.endIndex {
            let ch = line[i]

            if ch == "\"" {
                // Peek ahead: "" inside quotes is an escaped quote
                let next = line.index(after: i)
                if inQuotes && next < line.endIndex && line[next] == "\"" {
                    current.append("\"")
                    i = line.index(after: next)
                    continue
                }
                inQuotes.toggle()
            } else if ch == "," && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(ch)
            }
            i = line.index(after: i)
        }
        fields.append(current)
        return fields
    }

    /// Parse common Chase date formats: M/d/yyyy and MM/dd/yyyy.
    private static func parseDate(_ string: String) -> Date? {
        let formats = ["M/d/yyyy", "MM/dd/yyyy", "yyyy-MM-dd"]
        for format in formats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            if let date = formatter.date(from: string) {
                // Preserve the user's visible posting date. Normalizing to UTC
                // can shift Chase date-only rows back one day in Pacific time.
                return date
            }
        }
        return nil
    }
}
