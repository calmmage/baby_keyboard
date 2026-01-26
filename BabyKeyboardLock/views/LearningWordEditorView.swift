import SwiftUI

struct LearningWordEditorView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var randomWordList = RandomWordList.shared
    @State private var words: [LearningWord] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Learning Rotation")
                    .font(.headline)
                Spacer()
                Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                }
            }

            HStack {
                Text("Word")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Translation")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Tags")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Known")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Fav")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            List {
                ForEach(words.indices, id: \.self) { index in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(words[index].word)
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
                        Spacer()
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
                        Spacer()
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
                        Spacer()
                        Toggle("Known", isOn: Binding(
                            get: { words[index].known },
                            set: { newValue in
                                words[index].known = newValue
                                randomWordList.updateLearningWord(words[index])
                            }
                        ))
                        .labelsHidden()

                        Toggle("Fav", isOn: Binding(
                            get: { words[index].favorite },
                            set: { newValue in
                                words[index].favorite = newValue
                                randomWordList.updateLearningWord(words[index])
                            }
                        ))
                        .labelsHidden()
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(PlainListStyle())

            HStack {
                Button("Open CSV") {
                    randomWordList.openLearningCSV()
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .frame(width: 820, height: 650)
        .onAppear {
            words = randomWordList.getLearningWordList()
        }
        .onExitCommand {
            presentationMode.wrappedValue.dismiss()
        }
    }
}

#Preview {
    LearningWordEditorView()
}
