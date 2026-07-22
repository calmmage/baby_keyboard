import Foundation

extension Notification.Name {
    static let flashcardAssetCacheDidUpdate = Notification.Name("flashcardAssetCacheDidUpdate")
}

struct FlashcardImageSelection {
    let url: URL
    let rotationDegrees: Double
}

final class FlashcardAssetStore {
    static let shared = FlashcardAssetStore()

    private let fileManager = FileManager.default
    private let workQueue = DispatchQueue(label: "FlashcardAssetStore.work")
    private var inFlightDownloads: Set<String> = []

    private init() {}

    func imageSelection(for word: RandomWord, style: FlashcardStyle?) -> FlashcardImageSelection? {
        guard let style else {
            return nil
        }

        if let cachedRemoteSelection = cachedRemoteImageSelection(for: word, style: style) {
            return cachedRemoteSelection
        }

        if let bundledURL = bundledImageURL(for: word, style: style) {
            return FlashcardImageSelection(url: bundledURL, rotationDegrees: 0.0)
        }

        return nil
    }

    func bundledImageURL(for word: RandomWord, style: FlashcardStyle?) -> URL? {
        guard let style, !word.english.isEmpty else {
            return nil
        }

        let sanitizedWord = word.english.lowercased().replacingOccurrences(of: " ", with: "_")
        let styledBaseName = "\(style.rawValue)_\(sanitizedWord)"

        if let bundledImageURL = Bundle.main.url(forResource: styledBaseName, withExtension: "png") {
            return bundledImageURL
        }

        guard let resourcePath = Bundle.main.resourcePath else {
            return nil
        }

        let candidatePaths = [
            "\(resourcePath)/Resources/FlashcardImages/\(style.rawValue)/\(styledBaseName).png",
            "\(resourcePath)/Resources/\(styledBaseName).png",
            "\(resourcePath)/Resources/\(word.english.lowercased()).png",
        ]

        for path in candidatePaths where fileManager.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }

        return nil
    }

    private func cachedRemoteImageSelection(for word: RandomWord, style: FlashcardStyle) -> FlashcardImageSelection? {
        guard let asset = preferredRemoteImageAsset(for: word, style: style) else {
            return nil
        }

        let rotation = Double(asset.rotationDegrees ?? 0)
        let trimmedURI = asset.uri.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURI.isEmpty else {
            return nil
        }

        if let remoteURL = URL(string: trimmedURI),
           let scheme = remoteURL.scheme?.lowercased() {
            if scheme == "http" || scheme == "https" {
                let cachedURL = cacheFileURL(for: remoteURL)
                if fileManager.fileExists(atPath: cachedURL.path) {
                    return FlashcardImageSelection(url: cachedURL, rotationDegrees: rotation)
                }
                startDownloadIfNeeded(from: remoteURL, to: cachedURL)
                return nil
            }

            if scheme == "file" {
                return FlashcardImageSelection(url: remoteURL, rotationDegrees: rotation)
            }
        }

        let localURL = URL(fileURLWithPath: trimmedURI)
        guard fileManager.fileExists(atPath: localURL.path) else {
            return nil
        }
        return FlashcardImageSelection(url: localURL, rotationDegrees: rotation)
    }

    private func preferredRemoteImageAsset(for word: RandomWord, style: FlashcardStyle) -> WordDataAsset? {
        guard let entry = WordRepository.shared.entry(english: word.english, meaningKey: word.clarification) else {
            return nil
        }

        let candidates = entry.assets.filter { asset in
            asset.kind == .image && !asset.uri.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        guard !candidates.isEmpty else {
            return nil
        }

        return candidates.max { lhs, rhs in
            score(asset: lhs, word: word, style: style) < score(asset: rhs, word: word, style: style)
        }
    }

    private func score(asset: WordDataAsset, word: RandomWord, style: FlashcardStyle) -> Int {
        let uri = asset.uri.lowercased()
        let sanitizedWord = word.english.lowercased().replacingOccurrences(of: " ", with: "_")
        var score = 0

        if uri.contains("/\(style.rawValue)/") {
            score += 5
        }
        if uri.contains("\(style.rawValue)_\(sanitizedWord)") {
            score += 4
        }
        if uri.contains(sanitizedWord) {
            score += 2
        }
        if uri.contains(word.id.lowercased()) {
            score += 2
        }
        if let language = asset.language?.lowercased(), language.hasPrefix("en") {
            score += 1
        }

        return score
    }

    private func cacheFileURL(for remoteURL: URL) -> URL {
        let fileExtension = remoteURL.pathExtension.isEmpty ? "bin" : remoteURL.pathExtension
        let encoded = Data(remoteURL.absoluteString.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")

        return cacheDirectoryURL().appendingPathComponent("\(encoded).\(fileExtension)", isDirectory: false)
    }

    private func cacheDirectoryURL() -> URL {
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let appDirectory = baseDirectory.appendingPathComponent("BabyKeyboardLock", isDirectory: true)
        let cacheDirectory = appDirectory.appendingPathComponent("RemoteFlashcardAssets", isDirectory: true)

        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }

        return cacheDirectory
    }

    private func startDownloadIfNeeded(from remoteURL: URL, to destinationURL: URL) {
        let key = remoteURL.absoluteString
        let shouldStart: Bool = workQueue.sync {
            if inFlightDownloads.contains(key) {
                return false
            }
            inFlightDownloads.insert(key)
            return true
        }

        guard shouldStart else {
            return
        }

        URLSession.shared.downloadTask(with: remoteURL) { [weak self] temporaryURL, _, _ in
            defer {
                self?.workQueue.async {
                    self?.inFlightDownloads.remove(key)
                }
            }

            guard let self, let temporaryURL else {
                return
            }

            do {
                let parentDirectory = destinationURL.deletingLastPathComponent()
                if !self.fileManager.fileExists(atPath: parentDirectory.path) {
                    try self.fileManager.createDirectory(at: parentDirectory, withIntermediateDirectories: true)
                }
                if self.fileManager.fileExists(atPath: destinationURL.path) {
                    try self.fileManager.removeItem(at: destinationURL)
                }
                try self.fileManager.moveItem(at: temporaryURL, to: destinationURL)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .flashcardAssetCacheDidUpdate, object: destinationURL)
                }
            } catch {
                try? self.fileManager.removeItem(at: temporaryURL)
            }
        }.resume()
    }
}
