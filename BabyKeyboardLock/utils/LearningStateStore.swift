import Foundation
import SQLite3

final class LearningStateStore {
    private let appDirectoryName = "BabyKeyboardLock"
    private let databaseFileName = "learning_state.sqlite"
    private let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    func loadLearningWords() -> [LearningWord]? {
        guard let db = openDatabase() else {
            return nil
        }
        defer { sqlite3_close(db) }

        let query = """
        SELECT entry_id, word, clarification, translation, tags_json, known, favorite, seen_count, last_seen
        FROM learning_words
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(statement) }

        var rows: [LearningWord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = readText(column: 0, statement: statement) ?? ""
            if id.isEmpty { continue }

            let word = readText(column: 1, statement: statement) ?? ""
            let clarification = readText(column: 2, statement: statement) ?? ""
            let translation = readText(column: 3, statement: statement) ?? ""
            let tagsJSON = readText(column: 4, statement: statement) ?? "[]"
            let known = sqlite3_column_int(statement, 5) != 0
            let favorite = sqlite3_column_int(statement, 6) != 0
            let seenCount = Int(sqlite3_column_int(statement, 7))
            let lastSeenRaw = readText(column: 8, statement: statement)

            let tags = decodeTags(from: tagsJSON)
            let lastSeen = decodeDate(lastSeenRaw)

            rows.append(
                LearningWord(
                    id: id,
                    word: word,
                    clarification: clarification,
                    translation: translation,
                    tags: tags,
                    known: known,
                    favorite: favorite,
                    seenCount: seenCount,
                    lastSeen: lastSeen
                )
            )
        }
        return rows
    }

    func saveLearningWords(_ words: [LearningWord]) {
        guard let db = openDatabase() else {
            return
        }
        defer { sqlite3_close(db) }

        _ = execute(db: db, sql: "BEGIN IMMEDIATE TRANSACTION")
        _ = execute(db: db, sql: "DELETE FROM learning_words")

        let insertSQL = """
        INSERT INTO learning_words (
            entry_id, word, clarification, translation, tags_json, known, favorite, seen_count, last_seen
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
            _ = execute(db: db, sql: "ROLLBACK")
            return
        }
        defer { sqlite3_finalize(statement) }

        for word in words {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)

            bindText(word.id, at: 1, statement: statement)
            bindText(word.word, at: 2, statement: statement)
            bindText(word.clarification, at: 3, statement: statement)
            bindText(word.translation, at: 4, statement: statement)
            bindText(encodeTags(word.tags), at: 5, statement: statement)
            sqlite3_bind_int(statement, 6, word.known ? 1 : 0)
            sqlite3_bind_int(statement, 7, word.favorite ? 1 : 0)
            sqlite3_bind_int(statement, 8, Int32(word.seenCount))
            bindText(encodeDate(word.lastSeen), at: 9, statement: statement)

            if sqlite3_step(statement) != SQLITE_DONE {
                _ = execute(db: db, sql: "ROLLBACK")
                return
            }
        }

        _ = execute(db: db, sql: "COMMIT")
    }

    func databaseFileURL() -> URL? {
        resolveDatabaseURL()
    }

    private func openDatabase() -> OpaquePointer? {
        guard let url = resolveDatabaseURL() else {
            return nil
        }

        var db: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(url.path, &db, flags, nil) == SQLITE_OK, let db else {
            if let db {
                sqlite3_close(db)
            }
            return nil
        }

        guard ensureSchema(db: db) else {
            sqlite3_close(db)
            return nil
        }

        return db
    }

    private func ensureSchema(db: OpaquePointer) -> Bool {
        let createSQL = """
        CREATE TABLE IF NOT EXISTS learning_words (
            entry_id TEXT PRIMARY KEY,
            word TEXT NOT NULL,
            clarification TEXT NOT NULL,
            translation TEXT NOT NULL,
            tags_json TEXT NOT NULL,
            known INTEGER NOT NULL,
            favorite INTEGER NOT NULL,
            seen_count INTEGER NOT NULL,
            last_seen TEXT
        );
        """
        return execute(db: db, sql: createSQL)
    }

    private func resolveDatabaseURL() -> URL? {
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
        return appDir.appendingPathComponent(databaseFileName)
    }

    private func execute(db: OpaquePointer, sql: String) -> Bool {
        sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK
    }

    private func readText(column: Int32, statement: OpaquePointer?) -> String? {
        guard let value = sqlite3_column_text(statement, column) else {
            return nil
        }
        return String(cString: value)
    }

    private func bindText(_ value: String, at index: Int32, statement: OpaquePointer?) {
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, index, (value as NSString).utf8String, -1, transient)
    }

    private func encodeTags(_ tags: [String]) -> String {
        guard let data = try? JSONEncoder().encode(tags),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    private func decodeTags(from json: String) -> [String] {
        guard let data = json.data(using: .utf8),
              let tags = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return tags
    }

    private func encodeDate(_ date: Date?) -> String {
        guard let date else { return "" }
        return isoFormatter.string(from: date)
    }

    private func decodeDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        if let withFraction = isoFormatter.date(from: raw) {
            return withFraction
        }
        let fallback = ISO8601DateFormatter()
        if let parsed = fallback.date(from: raw) {
            return parsed
        }
        return nil
    }
}
