import Foundation

// MARK: - BookmarkedFolder
//
// One security-scoped folder bookmark persisted in UserDefaults. Collapses the
// previously-duplicated resolve-on-init / persist-on-set / start-stop-access
// blocks into a single reusable value (HANDOFF §5 predicted this extraction).
//
struct BookmarkedFolder {
    let key: String
    private let defaults: UserDefaults

    init(key: String, defaults: UserDefaults) {
        self.key = key
        self.defaults = defaults
    }

    /// Resolve the persisted bookmark to a URL, or nil if absent/unresolvable.
    func resolve() -> URL? {
        guard let data = defaults.data(forKey: key) else { return nil }
        var stale = false
        return try? URL(resolvingBookmarkData: data,
                        options: [.withSecurityScope],
                        relativeTo: nil,
                        bookmarkDataIsStale: &stale)
    }

    /// Persist `url` as a security-scoped bookmark (wraps start/stop access).
    func store(_ url: URL) {
        let started = url.startAccessingSecurityScopedResource()
        defer { if started { url.stopAccessingSecurityScopedResource() } }
        if let data = try? url.bookmarkData(options: [.withSecurityScope],
                                            includingResourceValuesForKeys: nil,
                                            relativeTo: nil) {
            defaults.set(data, forKey: key)
        }
    }

    /// Remove the persisted bookmark.
    func clear() {
        defaults.removeObject(forKey: key)
    }
}
