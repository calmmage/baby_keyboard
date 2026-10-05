import Foundation

final class WordCatalogStore {
    private let appDirectoryName = "BabyKeyboardLock"
    private let catalogFileName = "word_catalog.json"

    func loadCatalog() -> WordDataCatalog? {
        guard let url = resolveCatalogURL(),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let decoded = try? WordDataCatalog.decode(from: data) else {
            return nil
        }
        return decoded
    }

    @discardableResult
    func saveCatalog(_ catalog: WordDataCatalog) -> Bool {
        guard let url = resolveCatalogURL() else {
            return false
        }
        var normalized = catalog
        normalized.normalizeEntries()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(normalized) else {
            return false
        }
        do {
            try data.write(to: url, options: [.atomic])
            return true
        } catch {
            return false
        }
    }

    func clearCatalog() {
        guard let url = resolveCatalogURL(),
              FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        try? FileManager.default.removeItem(at: url)
    }

    func catalogFileURL() -> URL? {
        resolveCatalogURL()
    }

    private func resolveCatalogURL() -> URL? {
        guard let baseDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let appDir = baseDir.appendingPathComponent(appDirectoryName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: appDir.path) {
            do {
                try FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
            } catch {
                return nil
            }
        }
        return appDir.appendingPathComponent(catalogFileName)
    }
}
