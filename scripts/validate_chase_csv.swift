import Foundation

struct Row {
    let date: String
    let description: String
    let amount: Decimal
    let type: String
}

struct TenantSeed {
    let name: String
    let aliases: [String]
    let expectedRent: Decimal
    let property: String
}

func splitCSVLine(_ line: String) -> [String] {
    var fields: [String] = []
    var current = ""
    var inQuotes = false
    var i = line.startIndex

    while i < line.endIndex {
        let ch = line[i]
        if ch == "\"" {
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

func normalize(_ value: String) -> String {
    value
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        .lowercased()
        .replacingOccurrences(of: #"[^a-z0-9&'. ]+"#, with: " ", options: .regularExpression)
        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

func amountMatchesExpectedRent(_ amount: Decimal, _ expected: Decimal) -> Bool {
    guard expected > 0 else { return false }
    return abs(NSDecimalNumber(decimal: amount - expected).doubleValue) <= 2.0
}

func isIncomingRentPayment(description: String, type: String, amount: Decimal) -> Bool {
    guard amount > 0 else { return false }
    let text = normalize(description)
    let txType = normalize(type)
    return text.contains("zelle payment from")
        || text.contains("quickpay")
        || text.contains("rent pay")
        || txType.contains("quickpay credit")
        || txType.contains("partnerfi to chase")
        || txType.contains("ach credit")
}

func parseRows(from csvText: String) throws -> [Row] {
    let lines = csvText
        .components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }

    guard let header = lines.first else { return [] }
    let headers = splitCSVLine(header).map { normalize($0) }
    guard let dateIndex = headers.firstIndex(of: "posting date"),
          let descIndex = headers.firstIndex(of: "description"),
          let amountIndex = headers.firstIndex(of: "amount"),
          let typeIndex = headers.firstIndex(of: "type") else {
        throw NSError(domain: "ValidateCSV", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing required Chase columns"])
    }

    return lines.dropFirst().compactMap { line in
        let fields = splitCSVLine(line)
        guard fields.count > max(dateIndex, descIndex, amountIndex, typeIndex),
              let amount = Decimal(string: fields[amountIndex].replacingOccurrences(of: ",", with: "")) else {
            return nil
        }

        return Row(
            date: fields[dateIndex],
            description: fields[descIndex],
            amount: amount,
            type: fields[typeIndex]
        )
    }
}

let csvPath = CommandLine.arguments.dropFirst().first ?? "/Users/I818292/Downloads/Chase9817_Activity_20260513.CSV"
let csvText = try String(contentsOfFile: csvPath, encoding: .utf8)
let rows = try parseRows(from: csvText)

let tenants = [
    TenantSeed(name: "Yeisi Aguilar", aliases: ["YEISI MARILU AGUILAR HENRIQUEZ"], expectedRent: 2870, property: "Sample Property A"),
    TenantSeed(name: "Jose Alfaro", aliases: ["JOSE ALFARO"], expectedRent: 2900, property: "Sample Property B"),
    TenantSeed(name: "Lovella Salvador", aliases: ["LOVELLA SALVADOR"], expectedRent: 2680, property: "Sample Property C"),
    TenantSeed(name: "Duglas Giron", aliases: ["DUGLAS GIRON"], expectedRent: 2870, property: "Sample Property A"),
    TenantSeed(name: "Carlos Carranza", aliases: ["CARLOS CARRANZA"], expectedRent: 2600, property: "Sample Property D"),
    TenantSeed(name: "Felipe Soria", aliases: ["FELIPE SORIA"], expectedRent: 2850, property: "Sample Property E"),
    TenantSeed(name: "Mayra Torres", aliases: ["MAYRA TORRES HERNANDEZ", "MAYRA TORRES-HERNANDEZ"], expectedRent: 5000.50, property: "Sample Property F")
]

let incomingRentCandidates = rows.filter {
    isIncomingRentPayment(description: $0.description, type: $0.type, amount: $0.amount)
}

let outgoingZelle = rows.filter {
    normalize($0.description).contains("zelle payment to")
}

let matched = incomingRentCandidates.compactMap { row -> (Row, TenantSeed)? in
    let text = normalize(row.description)
    if let tenant = tenants.first(where: { tenant in
        ([tenant.name] + tenant.aliases)
            .map(normalize)
            .contains(where: { !$0.isEmpty && text.contains($0) })
    }) {
        return (row, tenant)
    }

    let amountMatches = tenants.filter { amountMatchesExpectedRent(row.amount, $0.expectedRent) }
    if amountMatches.count == 1, let tenant = amountMatches.first {
        return (row, tenant)
    }

    return nil
}

let pgandeUtilityRows = rows.filter {
    $0.amount < 0 && normalize($0.description).contains("pgande")
}

print("CSV path: \(csvPath)")
print("Parsed rows: \(rows.count)")
print("Incoming rent candidates: \(incomingRentCandidates.count)")
print("Outgoing Zelle payments ignored for rent: \(outgoingZelle.count)")
print("PGANDE utility rows: \(pgandeUtilityRows.count)")
print("Matched sample tenants: \(matched.count)")

for (row, tenant) in matched.sorted(by: { $0.0.date < $1.0.date }) {
    let amount = NSDecimalNumber(decimal: row.amount).stringValue
    print("- \(row.date) \(amount) -> \(tenant.name) / \(tenant.property)")
}

let expectedRows = 45
let expectedIncomingCandidates = 20
let expectedOutgoingZelle = 6
let expectedPGANDEUtilityRows = 4

guard rows.count == expectedRows else {
    fatalError("Expected \(expectedRows) parsed rows, got \(rows.count)")
}

guard incomingRentCandidates.count == expectedIncomingCandidates else {
    fatalError("Expected \(expectedIncomingCandidates) incoming rent candidates, got \(incomingRentCandidates.count)")
}

guard outgoingZelle.count == expectedOutgoingZelle else {
    fatalError("Expected \(expectedOutgoingZelle) outgoing Zelle payments, got \(outgoingZelle.count)")
}

guard pgandeUtilityRows.count == expectedPGANDEUtilityRows else {
    fatalError("Expected \(expectedPGANDEUtilityRows) PGANDE utility rows, got \(pgandeUtilityRows.count)")
}

guard matched.count >= 7 else {
    fatalError("Expected at least 7 seeded tenant matches, got \(matched.count)")
}

print("Validation passed.")
