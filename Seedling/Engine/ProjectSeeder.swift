import Foundation

// MARK: - ProjectSeeder
//
// Turns a typed project name into a new project folder under the user's
// "Projects home", then seeds the resolved `.md` files into it. The name
// births the folder *and* fills {{PROJECT_NAME}}. Never overwrites (the
// engine's safety property carries through).
//
// Security-scoped access to `home` is the caller's responsibility — this
// helper assumes `home` is already accessible.
enum ProjectSeeder {

    /// Turn raw user input into a filesystem-safe folder name. Replaces path
    /// separators with hyphens, drops control characters and leading dots, and
    /// trims/collapses whitespace. Spaces are preserved (folder names allow them).
    static func sanitize(_ raw: String) -> String {
        var s = raw.components(separatedBy: CharacterSet(charactersIn: "/\\:")).joined(separator: "-")
        s = s.components(separatedBy: .controlCharacters).joined()
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        while s.hasPrefix(".") { s.removeFirst() }
        s = s.split(whereSeparator: { $0 == " " || $0 == "\t" }).joined(separator: " ")
        return s
    }

    /// Create `home/<sanitized name>` (if needed) and seed `files` into it.
    /// Returns the seed result and the new folder URL.
    static func seed(projectName raw: String, into home: URL, files: [SeedFile]) throws -> (result: SeedResult, folder: URL) {
        let name = sanitize(raw)
        guard !name.isEmpty else { throw SeedError.emptyProjectName }
        let folder = home.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let options = ProjectOptions(folderURL: folder, projectName: name, tagline: "")
        let result = try Seedling.seed(files, into: folder, options: options)
        return (result, folder)
    }
}
