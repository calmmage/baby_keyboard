import Foundation
import Testing
@testable import BabyKeyboardLock

struct SharedLibraryClientTests {
    @Test func buildsVersionedFeedEndpoint() throws {
        let url = try SharedLibraryClient.endpointURL(
            baseURL: "http://localhost:3848/old/path?ignored=yes",
            includeDemo: true
        )

        #expect(url.absoluteString == "http://localhost:3848/api/shared-library?demo=1")
    }

    @Test func buildsWebPlayerURL() throws {
        let url = try SharedLibraryClient.playerURL(baseURL: "https://daria.example/")
        #expect(url.absoluteString == "https://daria.example/baby")
    }

    @Test func decodesSharedContract() throws {
        let json = """
        {
          "schemaVersion": 1,
          "generatedAt": "2026-07-11T08:00:00.000Z",
          "source": "demo",
          "items": [{
            "id": "demo-cat",
            "title": "Кот танцует",
            "createdAt": "2026-07-11T08:00:00.000Z",
            "image": {
              "id": "/demo/cat.svg",
              "kind": "image",
              "url": "http://localhost:3848/demo/cat.svg",
              "pathname": "/demo/cat.svg",
              "bytes": 0,
              "createdAt": "2026-07-11T08:00:00.000Z"
            },
            "videos": [],
            "music": null
          }],
          "warning": null
        }
        """

        let feed = try JSONDecoder().decode(SharedLibraryFeed.self, from: Data(json.utf8))
        #expect(feed.schemaVersion == 1)
        #expect(feed.items.first?.id == "demo-cat")
        #expect(feed.items.first?.image?.kind == .image)
    }
}
