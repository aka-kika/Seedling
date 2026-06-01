import Foundation

// MARK: - Generation error

enum SeedError: LocalizedError {
    case noFolderSelected
    case folderNotWritable
    case writeFailed(URL, underlying: Error)

    var errorDescription: String? {
        switch self {
        case .noFolderSelected:
            return "Choose a folder first."
        case .folderNotWritable:
            return "The selected folder is not writable."
        case .writeFailed(let url, let underlying):
            return "Couldn't write \(url.lastPathComponent): \(underlying.localizedDescription)"
        }
    }
}

// MARK: - Generation result

struct SeedResult {
    let created: [URL]
    let skipped: [URL]
    let folderURL: URL

    var createdNames: [String] {
        created.map { $0.lastPathComponent }
    }

    var summary: String {
        let c = created.count
        let s = skipped.count
        if c == 0 && s == 0 { return "No files selected." }
        if s == 0 { return "Created \(c) file\(c == 1 ? "" : "s")." }
        if c == 0 { return "All \(s) file\(s == 1 ? "" : "s") already existed — nothing changed." }
        return "Created \(c), skipped \(s) that already existed."
    }
}

// MARK: - Seedling engine

struct Seedling {

    /// Render the markdown body for a file, replacing `{{KEY}}` placeholders.
    static func render(_ file: SeedFile, options: ProjectOptions) -> String {
        var body = file.content
        body = body.replacingOccurrences(of: "{{PROJECT_NAME}}", with: options.projectName)
        body = body.replacingOccurrences(of: "{{TAGLINE}}",       with: options.tagline)
        return body
    }

    /// Run the seed operation: validate the folder, then create every enabled file.
    /// Skips files that already exist rather than overwriting.
    static func seed(_ files: [SeedFile], into folder: URL, options: ProjectOptions) throws -> SeedResult {
        guard !files.isEmpty else {
            return SeedResult(created: [], skipped: [], folderURL: folder)
        }

        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: folder.path, isDirectory: &isDir), isDir.boolValue else {
            throw SeedError.noFolderSelected
        }
        guard fm.isWritableFile(atPath: folder.path) else {
            throw SeedError.folderNotWritable
        }

        var created: [URL] = []
        var skipped: [URL] = []

        for file in files {
            let url = folder.appendingPathComponent(file.name)
            if fm.fileExists(atPath: url.path) {
                skipped.append(url)
                continue
            }
            let body = render(file, options: options)
            do {
                try body.write(to: url, atomically: true, encoding: .utf8)
                created.append(url)
            } catch {
                throw SeedError.writeFailed(url, underlying: error)
            }
        }

        return SeedResult(created: created, skipped: skipped, folderURL: folder)
    }
}
