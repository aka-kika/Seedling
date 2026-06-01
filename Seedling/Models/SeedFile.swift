import Foundation
import SwiftUI
import Combine

// MARK: - SeedFile

/// A single markdown file that can be generated into a new project.
struct SeedFile: Identifiable, Hashable {
    let id: String          // stable identifier, e.g. "readme"
    let name: String        // file name with .md, e.g. "README.md"
    let icon: String        // SF Symbol
    let description: String // one-line description
    let category: Category  // grouping (for any future UI)
    let content: String     // markdown body
    let defaultEnabled: Bool
    let source: Source

    enum Category: String, CaseIterable, Identifiable, Hashable {
        case overview
        case ai
        case workflow
        case community
        case meta

        var id: String { rawValue }

        var title: String {
            switch self {
            case .overview:  return "Overview"
            case .ai:        return "AI & Agents"
            case .workflow:  return "Workflow"
            case .community: return "Community"
            case .meta:      return "Meta"
            }
        }

        var icon: String {
            switch self {
            case .overview:  return "doc.text"
            case .ai:        return "person.2"
            case .workflow:  return "terminal"
            case .community: return "person.2.crop.square.stack"
            case .meta:      return "tray"
            }
        }
    }

    enum Source: Hashable {
        case builtIn
        case userFolder
    }
}

// MARK: - SeedLibrary

/// Built-in library of seed files. Ships with the app.
enum SeedLibrary {
    static let files: [SeedFile] = [
        SeedFile(
            id: "readme",
            name: "README.md",
            icon: "doc.text",
            description: "Project overview and quickstart",
            category: .overview,
            content: """
            # \(placeholder("PROJECT_NAME"))

            \(placeholder("TAGLINE"))

            ## Quickstart

            ```bash
            # install
            # build
            # run
            ```

            ## Layout

            ```
            .
            ├── src/
            ├── tests/
            └── docs/
            ```

            ## Notes

            -
            """,
            defaultEnabled: true,
            source: .builtIn
        ),
        SeedFile(
            id: "agents",
            name: "AGENTS.md",
            icon: "person.2",
            description: "Guidance for AI coding assistants",
            category: .ai,
            content: """
            # AGENTS

            Instructions for AI coding agents working in this repository.

            ## Stack

            - Language:
            - Framework:
            - Package manager:

            ## Conventions

            - Code style:
            - Testing:
            - Commits:

            ## Boundaries

            - Do not touch:
            - Ask before:

            ## Local commands

            ```bash
            # install
            # test
            # lint
            ```
            """,
            defaultEnabled: true,
            source: .builtIn
        ),
        SeedFile(
            id: "commands",
            name: "COMMANDS.md",
            icon: "terminal",
            description: "Cheat sheet of project commands",
            category: .workflow,
            content: """
            # Commands

            Common commands for working on this project.

            ## Setup

            ```bash
            ```

            ## Develop

            ```bash
            ```

            ## Test

            ```bash
            ```

            ## Ship

            ```bash
            ```
            """,
            defaultEnabled: true,
            source: .builtIn
        ),
        SeedFile(
            id: "contributing",
            name: "CONTRIBUTING.md",
            icon: "person.crop.circle.badge.plus",
            description: "How to contribute",
            category: .community,
            content: """
            # Contributing

            Thanks for helping improve \(placeholder("PROJECT_NAME")).

            ## Workflow

            1. Fork and branch
            2. Make your change
            3. Open a pull request

            ## Pull requests

            - Keep them small
            - Add a clear description
            - Link related issues

            ## Reporting issues

            Use the issue tracker. Include reproduction steps where relevant.
            """,
            defaultEnabled: true,
            source: .builtIn
        ),
        SeedFile(
            id: "changelog",
            name: "CHANGELOG.md",
            icon: "list.bullet.rectangle",
            description: "Release history",
            category: .meta,
            content: """
            # Changelog

            All notable changes to this project will be documented here.

            ## [Unreleased]

            ### Added

            -

            ### Changed

            -

            ### Fixed

            -
            """,
            defaultEnabled: false,
            source: .builtIn
        ),
        SeedFile(
            id: "license",
            name: "LICENSE.md",
            icon: "lock.shield",
            description: "License terms",
            category: .meta,
            content: """
            # License

            TODO: add license name and year.
            """,
            defaultEnabled: true,
            source: .builtIn
        ),
        SeedFile(
            id: "codeowners",
            name: "CODEOWNERS.md",
            icon: "person.badge.shield.checkmark",
            description: "Code ownership map",
            category: .community,
            content: """
            # Codeowners

            | Path | Owner |
            | ---- | ----- |
            | /    |       |

            Update this table as the team grows.
            """,
            defaultEnabled: false,
            source: .builtIn
        ),
        SeedFile(
            id: "security",
            name: "SECURITY.md",
            icon: "checkmark.shield",
            description: "Security policy",
            category: .community,
            content: """
            # Security

            ## Reporting a vulnerability

            Email: TODO

            Please do not file a public issue for security problems.
            """,
            defaultEnabled: false,
            source: .builtIn
        ),
        SeedFile(
            id: "todos",
            name: "TODOS.md",
            icon: "checklist",
            description: "Open tasks and follow-ups",
            category: .workflow,
            content: """
            # TODOs

            - [ ] First task
            - [ ] Second task
            - [ ] Third task
            """,
            defaultEnabled: false,
            source: .builtIn
        ),
        SeedFile(
            id: "notes",
            name: "NOTES.md",
            icon: "note.text",
            description: "Free-form working notes",
            category: .meta,
            content: """
            # Notes

            Workspace for scratch ideas, decisions, and context.
            """,
            defaultEnabled: false,
            source: .builtIn
        )
    ]

    /// Files written by the Seed action when no templates folder is set.
    /// Built-in defaults that come out of the box.
    static var defaultSeedSet: [SeedFile] {
        files.filter { $0.defaultEnabled }
    }
}

// MARK: - Helpers

/// `Seedling` placeholder syntax: `{{KEY}}`. Replaced at write time.
func placeholder(_ key: String) -> String { "{{\(key)}}" }

// MARK: - Project options (folder + name + tagline)

struct ProjectOptions {
    var folderURL: URL?
    var projectName: String
    var tagline: String
}

// MARK: - App Settings (persisted user preferences)

/// Persisted app settings: templates folder bookmark + appearance.
@MainActor
final class AppSettings: ObservableObject {
    private let defaults: UserDefaults
    private let templatesBookmarkKey = "seedling.templatesFolderBookmark"
    private let appearanceKey = "seedling.appearance"
    private let lastFolderBookmarkKey = "seedling.lastFolderBookmark"
    private let lastProjectNameKey = "seedling.lastProjectName"
    private let lastTaglineKey = "seedling.lastTagline"
    private let globalHotKeyEnabledKey = "seedling.globalHotKeyEnabled"

    @Published var templatesFolderURL: URL? {
        didSet { persistTemplatesBookmark() }
    }

    /// Whether the system-wide ⌥⌘S summon hotkey is active. Persisted; defaults to on.
    @Published var globalHotKeyEnabled: Bool {
        didSet { defaults.set(globalHotKeyEnabled, forKey: globalHotKeyEnabledKey) }
    }

    /// Most recently seeded destination folder, with security-scoped bookmark.
    /// Re-opens the popover with this folder pre-selected so re-seeding is one click.
    @Published private(set) var lastFolderURL: URL?
    @Published private(set) var lastProjectName: String = ""
    @Published private(set) var lastTagline: String = ""

    @Published var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: appearanceKey) }
    }

    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
        var title: String {
            switch self {
            case .system: return "System"
            case .light:  return "Light"
            case .dark:   return "Dark"
            }
        }
        /// HIG: SF Symbol name for the segmented picker.
        var symbolName: String {
            switch self {
            case .system: return "circle.righthalf.filled"
            case .light:  return "sun.max"
            case .dark:   return "moon.fill"
            }
        }
        /// Legacy alias for the popover / right-click menu code paths.
        var icon: String { symbolName }
        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light:  return .light
            case .dark:   return .dark
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedAppearance = defaults.string(forKey: appearanceKey) ?? Appearance.system.rawValue
        self.appearance = Appearance(rawValue: storedAppearance) ?? .system

        // Default to on when the key has never been written.
        self.globalHotKeyEnabled = defaults.object(forKey: globalHotKeyEnabledKey) as? Bool ?? true

        if let data = defaults.data(forKey: templatesBookmarkKey) {
            var stale = false
            if let url = try? URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) {
                self.templatesFolderURL = url
            }
        }

        if let data = defaults.data(forKey: lastFolderBookmarkKey) {
            var stale = false
            if let url = try? URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) {
                self.lastFolderURL = url
            }
        }
        self.lastProjectName = defaults.string(forKey: lastProjectNameKey) ?? ""
        self.lastTagline = defaults.string(forKey: lastTaglineKey) ?? ""
    }

    /// Record the destination folder / name / tagline from a successful seed.
    /// Stores a security-scoped bookmark so the folder can be re-accessed next launch.
    func recordSeed(folder: URL, projectName: String, tagline: String) {
        let didStart = folder.startAccessingSecurityScopedResource()
        defer { if didStart { folder.stopAccessingSecurityScopedResource() } }

        lastFolderURL = folder
        lastProjectName = projectName
        lastTagline = tagline

        if let data = try? folder.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            defaults.set(data, forKey: lastFolderBookmarkKey)
        }
        defaults.set(projectName, forKey: lastProjectNameKey)
        defaults.set(tagline, forKey: lastTaglineKey)
    }

    /// Pick a templates folder. Stores a security-scoped bookmark for sandboxed re-access.
    func setTemplatesFolder(from url: URL) {
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }
        templatesFolderURL = url
    }

    private func persistTemplatesBookmark() {
        guard let url = templatesFolderURL else {
            defaults.removeObject(forKey: templatesBookmarkKey)
            return
        }
        do {
            let data = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            defaults.set(data, forKey: templatesBookmarkKey)
        } catch {
            // ignore — the folder will not survive across launches
        }
    }

    /// The set of files a Seed will write: the user's templates folder if it's set and
    /// non-empty, otherwise the built-in defaults. Single source of truth shared by the
    /// popover and the Finder Service. Wraps security-scoped access internally.
    func resolveSeedFiles() -> [SeedFile] {
        if templatesFolderURL != nil {
            let started = beginTemplatesAccess()
            defer { if started { endTemplatesAccess() } }
            if let url = templatesFolderURL {
                let loaded = TemplateLoader.load(from: url)
                if !loaded.files.isEmpty { return loaded.files }
            }
        }
        return SeedLibrary.defaultSeedSet
    }

    /// Begin security-scoped access for the templates folder. Caller must `endAccess` after use.
    func beginTemplatesAccess() -> Bool {
        guard let url = templatesFolderURL else { return false }
        return url.startAccessingSecurityScopedResource()
    }

    func endTemplatesAccess() {
        templatesFolderURL?.stopAccessingSecurityScopedResource()
    }
}
