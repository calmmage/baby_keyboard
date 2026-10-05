import SwiftUI

struct LearningWordEditorView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var randomWordList = RandomWordList.shared
    @State private var words: [LearningWord] = []
    @State private var showOnlyPool: Bool

    init(initialShowOnlyPool: Bool = false) {
        _showOnlyPool = State(initialValue: initialShowOnlyPool)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Learning Rotation")
                    .font(.headline)
                Spacer()
                Toggle("Show only current pool", isOn: $showOnlyPool)
                    .onChange(of: showOnlyPool) {
                        refreshWords()
                    }
                Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                }
            }

            HStack {
                Text("Word")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 120, alignment: .leading)
                Text("Translation")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 100, alignment: .leading)
                Text("Tags")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 150, alignment: .leading)
                Text("Seen")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .center)
                Text("Known")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .center)
                Text("Fav")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .center)
            }

            List {
                ForEach(words.indices, id: \.self) { index in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(words[index].word)
                                .font(.system(size: 13))
                            TextField(
                                "clarification",
                                text: Binding(
                                    get: { words[index].clarification },
                                    set: { newValue in
                                        words[index].clarification = newValue
                                        randomWordList.updateLearningWord(words[index])
                                        words[index].id = randomWordList.getLearningWordId(for: words[index])
                                    }
                                )
                            )
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                        }
                        .frame(width: 120, alignment: .leading)

                        TextField(
                            "translation",
                            text: Binding(
                                get: { words[index].translation },
                                set: { newValue in
                                    words[index].translation = newValue
                                    randomWordList.updateLearningWord(words[index])
                                }
                            )
                        )
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .frame(width: 100)

                        TextField(
                            "tags",
                            text: Binding(
                                get: { words[index].tags.joined(separator: ",") },
                                set: { newValue in
                                    words[index].tags = newValue
                                        .split(separator: ",")
                                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                                        .filter { !$0.isEmpty }
                                    randomWordList.updateLearningWord(words[index])
                                }
                            )
                        )
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .frame(width: 150)

                        Text("\(words[index].seenCount)")
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 50, alignment: .center)

                        Toggle("Known", isOn: Binding(
                            get: { words[index].known },
                            set: { newValue in
                                words[index].known = newValue
                                randomWordList.updateLearningWord(words[index])
                            }
                        ))
                        .labelsHidden()
                        .frame(width: 60, alignment: .center)

                        Toggle("Fav", isOn: Binding(
                            get: { words[index].favorite },
                            set: { newValue in
                                words[index].favorite = newValue
                                randomWordList.updateLearningWord(words[index])
                            }
                        ))
                        .labelsHidden()
                        .frame(width: 50, alignment: .center)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(PlainListStyle())

            HStack {
                Button("Open Learning Data") {
                    randomWordList.openLearningDatabase()
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .frame(width: 900, height: 650)
        .onAppear {
            refreshWords()
        }
        .onExitCommand {
            presentationMode.wrappedValue.dismiss()
        }
    }

    private func refreshWords() {
        if showOnlyPool {
            words = randomWordList.getCurrentLearningPool()
        } else {
            words = randomWordList.getLearningWordList()
        }
    }
}

#Preview {
    LearningWordEditorView()
}
