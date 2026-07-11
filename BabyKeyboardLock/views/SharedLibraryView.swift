import AVFoundation
import AppKit
import Combine
import SwiftUI

let SharedLibraryWindowID = "sharedLibraryWindow"

@MainActor
final class SharedLibraryViewModel: ObservableObject {
    @Published private(set) var feed: SharedLibraryFeed?
    @Published private(set) var currentIndex = 0
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    var currentItem: SharedLibraryItem? {
        guard let items = feed?.items, items.indices.contains(currentIndex) else { return nil }
        return items[currentIndex]
    }

    func load(baseURL: String, pin: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let loadedFeed = try await SharedLibraryClient().fetch(
                baseURL: baseURL,
                pin: pin.isEmpty ? nil : pin
            )
            feed = loadedFeed
            currentIndex = 0
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func advance() {
        guard let count = feed?.items.count, count > 0 else { return }
        currentIndex = (currentIndex + 1) % count
    }
}

struct SharedLibraryView: View {
    @AppStorage("sharedLibraryBaseURL") private var baseURL = "http://localhost:3848"
    @AppStorage("sharedLibraryRewardMode") private var rewardMode = false
    @AppStorage("wordDisplayDuration") private var rewardDuration = DEFAULT_WORD_DISPLAY_DURATION
    @State private var pin = ""
    @State private var rewardVisible = false
    @State private var rewardSequence = 0
    @StateObject private var model = SharedLibraryViewModel()
    @ObservedObject private var eventHandler = EventHandler.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daria Shared Library")
                        .font(.headline)
                    Text("One creation feed for web + Mac")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                TextField("http://localhost:3848", text: $baseURL)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)
                SecureField("PIN (optional)", text: $pin)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 125)
                Toggle("Reward mode", isOn: $rewardMode)
                    .toggleStyle(.switch)
                    .help("Reveal a creation only after a correct learning answer")
                Button("Reload") {
                    Task { await model.load(baseURL: baseURL, pin: pin) }
                }
                Button("Open web") {
                    openWebPlayer()
                }
            }
            .padding(14)

            Divider()

            Group {
                if model.isLoading && model.feed == nil {
                    ProgressView("Loading shared creations…")
                } else if let errorMessage = model.errorMessage, model.feed == nil {
                    VStack(spacing: 12) {
                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Button("Try again") {
                            Task { await model.load(baseURL: baseURL, pin: pin) }
                        }
                    }
                    .padding(30)
                } else if rewardMode && !rewardVisible {
                    VStack(spacing: 14) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 54))
                            .foregroundStyle(.yellow)
                        Text("Complete a word to reveal a creation")
                            .font(.title2.bold())
                        Text("A correct gamified letter or a completed typing word unlocks the next shared story.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .padding(32)
                } else if let item = model.currentItem {
                    ZStack(alignment: .bottom) {
                        SharedLibraryMediaView(item: item)
                            .id(item.id)
                            .contentShape(Rectangle())
                            .onTapGesture { model.advance() }

                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                    .font(.title2.bold())
                                Text(statusLine)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Next") { model.advance() }
                                .keyboardShortcut(.space, modifiers: [])
                        }
                        .padding(16)
                        .background(.ultraThinMaterial)
                    }
                } else {
                    Text("Nothing to play yet")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        }
        .frame(minWidth: 820, minHeight: 620)
        .task {
            await model.load(baseURL: baseURL, pin: pin)
        }
        .onReceive(eventHandler.$lastKeyString.dropFirst()) { _ in
            guard !rewardMode, eventHandler.isLocked else { return }
            model.advance()
        }
        .onReceive(NotificationCenter.default.publisher(for: .learningRewardEarned)) { _ in
            guard rewardMode else { return }
            model.advance()
            rewardVisible = true
            rewardSequence += 1
        }
        .onChange(of: rewardMode) { _, _ in
            rewardVisible = false
        }
        .task(id: rewardSequence) {
            guard rewardMode, rewardVisible else { return }
            let seconds = max(rewardDuration, 2)
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            rewardVisible = false
        }
    }

    private var statusLine: String {
        let source = model.feed?.source == "demo" ? "demo feed" : "shared creation feed"
        let keyHint: String
        if rewardMode {
            keyHint = rewardVisible ? "learning reward unlocked" : "waiting for a correct answer"
        } else {
            keyHint = eventHandler.isLocked ? "any blocked key advances" : "lock keyboard to use any key"
        }
        return "\(source) · contract v\(model.feed?.schemaVersion ?? 0) · \(keyHint)"
    }

    private func openWebPlayer() {
        guard let url = try? SharedLibraryClient.playerURL(baseURL: baseURL) else { return }
        NSWorkspace.shared.open(url)
    }
}

private struct SharedLibraryMediaView: View {
    let item: SharedLibraryItem
    @State private var phase: SharedLibraryMediaKind = .image
    @State private var musicPlayer: AVPlayer?

    private var video: SharedLibraryAsset? { item.videos.first }

    var body: some View {
        ZStack {
            Color.black

            if phase == .image, let image = item.image {
                AsyncImage(url: image.url) { loadPhase in
                    switch loadPhase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .failure:
                        ContentUnavailableView("Image unavailable", systemImage: "photo")
                    case .empty:
                        ProgressView()
                    @unknown default:
                        EmptyView()
                    }
                }
            } else if phase == .video, let video {
                LoopingVideoView(url: video.url)
            } else {
                ContentUnavailableView("No playable media", systemImage: "play.slash")
            }
        }
        .task(id: item.id) {
            musicPlayer?.pause()
            musicPlayer = item.music.map { AVPlayer(url: $0.url) }
            musicPlayer?.play()

            phase = item.image == nil && video != nil ? .video : .image
            guard item.image != nil, video != nil else { return }
            try? await Task.sleep(for: .milliseconds(1600))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.25)) {
                phase = .video
            }
        }
        .onDisappear {
            musicPlayer?.pause()
            musicPlayer = nil
        }
    }
}
