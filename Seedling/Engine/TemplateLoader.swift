import Foundation
import AppKit

// MARK: - Template Loader

/// Loads `.md` files from a user-chosen folder and converts them into `SeedFile`s.
/// The user can keep their own templates directory (e.g. on iCloud or Dropbox)
/// and Seedling will pick up whatever is in there.
enum TemplateLoader {

    /// Result of a folder scan. `errors` are non-fatal (a file we couldn't read).
    struct LoadResult {
        let files: [SeedFile]
        let errors: [String]
    }

    /// Scan a folder for `.md` files (one level deep, non-recursive) and produce
    /// seed files. Skips files we can't read.
    static func load(from folder: URL) -> LoadResult {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey, .nameKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else {
            return LoadResult(files: [], errors: ["Couldn't read folder."])
        }

        let mdFiles = contents.filter { $0.pathExtension.lowercased() == "md" }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }

        var loaded: [SeedFile] = []
        var errors: [String] = []

        for url in mdFiles {
            do {
                let body = try String(contentsOf: url, encoding: .utf8)
                let file = makeFile(from: url, content: body)
                loaded.append(file)
            } catch {
                errors.append("Skipped \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }

        return LoadResult(files: loaded, errors: errors)
    }

    private static func makeFile(from url: URL, content: String) -> SeedFile {
        let name = url.lastPathComponent
        let id = "user:" + name.lowercased()
        return SeedFile(
            id: id,
            name: name,
            icon: iconFor(name: name),
            description: "From your templates folder",
            category: .meta,
            content: content,
            defaultEnabled: false,
            source: .userFolder
        )
    }

    private static func iconFor(name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("readme")     { return "doc.text" }
        if lower.contains("agent")      { return "person.2" }
        if lower.contains("command")    { return "terminal" }
        if lower.contains("contribut")  { return "person.crop.circle.badge.plus" }
        if lower.contains("changelog")  { return "list.bullet.rectangle" }
        if lower.contains("license")    { return "lock.shield" }
        if lower.contains("codeowner")  { return "person.badge.shield.checkmark" }
        if lower.contains("security")   { return "checkmark.shield" }
        if lower.contains("todo")       { return "checklist" }
        if lower.contains("note")       { return "note.text" }
        return "doc"
    }
}
