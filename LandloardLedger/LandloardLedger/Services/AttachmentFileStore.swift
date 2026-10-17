import Foundation
import UniformTypeIdentifiers

struct StoredAttachmentFile {
    let fileName: String
    let storedFileName: String
    let contentTypeIdentifier: String
    let fileSize: Int64
}

enum AttachmentFileStore {

    private static let folderName = "TransactionAttachments"

    static func copyIntoStore(from sourceURL: URL) throws -> StoredAttachmentFile {
        let didStartAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let directory = try attachmentsDirectory()
        let fileExtension = sourceURL.pathExtension
        let storedFileName = UUID().uuidString + (fileExtension.isEmpty ? "" : ".\(fileExtension)")
        let destinationURL = directory.appendingPathComponent(storedFileName, conformingTo: contentType(for: sourceURL))

        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

        let values = try destinationURL.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey])
        let typeIdentifier = values.contentType?.identifier ?? contentType(for: sourceURL).identifier

        return StoredAttachmentFile(
            fileName: sourceURL.lastPathComponent,
            storedFileName: storedFileName,
            contentTypeIdentifier: typeIdentifier,
            fileSize: Int64(values.fileSize ?? 0)
        )
    }

    static func fileURL(for attachment: TransactionAttachment) throws -> URL {
        try attachmentsDirectory().appendingPathComponent(attachment.storedFileName)
    }

    static func deleteFile(for attachment: TransactionAttachment) {
        guard let fileURL = try? fileURL(for: attachment) else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }

    private static func attachmentsDirectory() throws -> URL {
        let applicationSupportURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = applicationSupportURL.appendingPathComponent(folderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private static func contentType(for url: URL) -> UTType {
        if let type = UTType(filenameExtension: url.pathExtension) {
            return type
        }
        return .data
    }
}
