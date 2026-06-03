#!/usr/bin/env swift
//
//  smoke_test.swift
//  Seedling
//
//  End-to-end test of the engine. Run with: `swift scripts/smoke_test.swift`
//
//  This script is self-contained: it inlines the minimal engine + model
//  types so the test can be run without an Xcode build. The inlined
//  types mirror the production code; if you change Seedling.swift or
//  SeedFile.swift, mirror the change here.
//

import Foundation

// MARK: - Inlined types (mirror Models/SeedFile.swift + Engine/Seedling.swift)

struct SeedFile {
    let name: String
    let content: String
}

struct ProjectOptions {
    var folderURL: URL?
    var projectName: String
    var tagline: String
}

struct SeedResult {
    let created: [URL]
    let skipped: [URL]
    let folderURL: URL
}

enum SeedError: Error, LocalizedError {
    case noFolderSelected
    case folderNotWritable
    case writeFailed(URL, underlying: Error)
    case emptyProjectName

    var errorDescription: String? {
        switch self {
        case .noFolderSelected:
            return "Choose a folder first."
        case .folderNotWritable:
            return "The selected folder is not writable."
        case .writeFailed(let url, let underlying):
            return "Couldn't write \(url.lastPathComponent): \(underlying.localizedDescription)"
        case .emptyProjectName:
            return "Type a project name first."
        }
    }
}

enum Seedling {
    static func render(_ file: SeedFile, options: ProjectOptions) -> String {
        var body = file.content
        body = body.replacingOccurrences(of: "{{PROJECT_NAME}}", with: options.projectName)
        body = body.replacingOccurrences(of: "{{TAGLINE}}",       with: options.tagline)
        return body
    }

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

enum ProjectSeeder {
    static func sanitize(_ raw: String) -> String {
        var s = raw.components(separatedBy: CharacterSet(charactersIn: "/\\:")).joined(separator: "-")
        s = s.components(separatedBy: .controlCharacters).joined()
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        while s.hasPrefix(".") { s.removeFirst() }
        s = s.split(whereSeparator: { $0 == " " || $0 == "\t" }).joined(separator: " ")
        return s
    }

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

// MARK: - Tests

let fm = FileManager.default
let tmp = fm.temporaryDirectory.appendingPathComponent("seedling-smoke-\(UUID().uuidString)")
try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
defer { try? fm.removeItem(at: tmp) }

print("--- Seedling smoke test ---")
print("Destination: \(tmp.path)\n")

// 1. Built-in defaults are present
let defaults: [SeedFile] = [
    SeedFile(name: "README.md",        content: "# {{PROJECT_NAME}}\n\n{{TAGLINE}}"),
    SeedFile(name: "AGENTS.md",        content: "agents for {{PROJECT_NAME}}"),
    SeedFile(name: "COMMANDS.md",      content: "commands for {{PROJECT_NAME}}"),
    SeedFile(name: "CONTRIBUTING.md",  content: "contributing to {{PROJECT_NAME}}"),
    SeedFile(name: "LICENSE.md",       content: "license for {{PROJECT_NAME}}")
]
precondition(defaults.count == 5, "should have 5 default files")
print("✓ 5 default files defined")

// 2. Seed action writes the default set into a real folder
let options = ProjectOptions(folderURL: tmp, projectName: "smoke-test", tagline: "A smoke test project")
let result = try Seedling.seed(defaults, into: tmp, options: options)
precondition(result.created.count == 5, "all 5 should be created")
precondition(result.skipped.isEmpty, "nothing should be skipped on a fresh folder")
print("✓ 5 files created, 0 skipped on first pass")

// 3. Verify placeholder substitution worked
let readme = try String(contentsOf: tmp.appendingPathComponent("README.md"), encoding: .utf8)
precondition(readme.contains("# smoke-test"), "project name should be substituted in README")
precondition(readme.contains("A smoke test project"), "tagline should be substituted in README")
print("✓ {{PROJECT_NAME}} and {{TAGLINE}} placeholders substituted correctly")
// 4. Re-seed should skip all existing files
let result2 = try Seedling.seed(defaults, into: tmp, options: options)
precondition(result2.created.isEmpty, "nothing should be created on second pass")
precondition(result2.skipped.count == 5, "everything should be skipped on second pass")
print("✓ 0 created, 5 skipped on re-seed (never overwrites)")

// 5. Partial seed (some new, some existing)
let partial: [SeedFile] = [
    SeedFile(name: "README.md",  content: "updated"),  // exists
    SeedFile(name: "CHANGELOG.md", content: "new")     // new
]
let result3 = try Seedling.seed(partial, into: tmp, options: options)
precondition(result3.created.count == 1, "only CHANGELOG should be created")
precondition(result3.skipped.count == 1, "only README should be skipped")
let readmeAfter = try String(contentsOf: tmp.appendingPathComponent("README.md"), encoding: .utf8)
precondition(readmeAfter == "# smoke-test\n\nA smoke test project", "README should be untouched")
print("✓ Partial seed: 1 created, 1 skipped, existing file untouched")

// 6. Invalid folder should throw
do {
    let bad = URL(fileURLWithPath: "/nonexistent/path/that/does/not/exist")
    _ = try Seedling.seed(defaults, into: bad, options: options)
    precondition(false, "should have thrown")
} catch SeedError.noFolderSelected {
    print("✓ Invalid folder throws SeedError.noFolderSelected")
}

// 7. Name sanitization
precondition(ProjectSeeder.sanitize("aurora") == "aurora", "plain name unchanged")
precondition(ProjectSeeder.sanitize("  spaced out  ") == "spaced out", "trims + collapses whitespace")
precondition(ProjectSeeder.sanitize("a/b:c") == "a-b-c", "path separators become hyphens")
precondition(ProjectSeeder.sanitize("...dotfile") == "dotfile", "strips leading dots")
precondition(ProjectSeeder.sanitize("   ") == "", "whitespace-only becomes empty")
print("✓ Project name sanitization")

// 8. Birth a subfolder and seed it
let home = tmp.appendingPathComponent("home-\(UUID().uuidString)")
try fm.createDirectory(at: home, withIntermediateDirectories: true)
let born = try ProjectSeeder.seed(projectName: "aurora", into: home, files: defaults)
precondition(born.folder.lastPathComponent == "aurora", "subfolder named after the project")
precondition(born.result.created.count == 5, "all 5 seeds planted into the new folder")
let reborn = try ProjectSeeder.seed(projectName: "aurora", into: home, files: defaults)
precondition(reborn.result.created.isEmpty && reborn.result.skipped.count == 5, "re-seed never overwrites")
print("✓ ProjectSeeder births a folder and seeds it (never overwrites)")

// 9. Empty name is rejected
do {
    _ = try ProjectSeeder.seed(projectName: "   ", into: home, files: defaults)
    precondition(false, "should have thrown")
} catch SeedError.emptyProjectName {
    print("✓ Empty project name throws SeedError.emptyProjectName")
}

print("\nAll smoke tests passed ✅")
