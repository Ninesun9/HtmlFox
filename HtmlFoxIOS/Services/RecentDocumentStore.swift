import Foundation

struct RecentDocumentStore {
    private let key = "htmlfox.recentDocuments"

    func load() -> [RecentDocument] {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return []
        }
        return (try? JSONDecoder().decode([RecentDocument].self, from: data)) ?? []
    }

    func upsert(_ item: RecentDocument, into items: [RecentDocument]) -> [RecentDocument] {
        var next = items.filter { $0.fileName != item.fileName }
        next.insert(item, at: 0)
        next = Array(next.prefix(20))
        save(next)
        return next
    }

    func remove(_ item: RecentDocument, from items: [RecentDocument]) -> [RecentDocument] {
        let next = items.filter { $0.fileName != item.fileName }
        save(next)
        return next
    }

    private func save(_ items: [RecentDocument]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
