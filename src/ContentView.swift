import SwiftUI

struct ContentView: View {
    @StateObject private var model = ChatModel()

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                sourceControls
                if model.isSettingsVisible {
                    settingsPanel
                }
                if model.isContextVisible {
                    contextPanel
                }
                messages
                composer
            }
            .padding(14)
        }
        .frame(minWidth: 900, minHeight: 660)
        .onAppear {
            model.start()
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            HStack(spacing: 7) {
                Circle().fill(Color(red: 1.0, green: 0.34, blue: 0.32)).frame(width: 11, height: 11)
                Circle().fill(Color(red: 1.0, green: 0.78, blue: 0.25)).frame(width: 11, height: 11)
                Circle().fill(Color(red: 0.30, green: 0.84, blue: 0.42)).frame(width: 11, height: 11)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(">_")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.terminalGreen)
                    Text("Gemma Desktop")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.text)
                }
                Text("local coding companion")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppTheme.muted)
            }

            Spacer()

            StatusPill(label: "model", value: model.settings.model, accent: AppTheme.amber)
                .frame(maxWidth: 230)
            StatusPill(label: "bridge", value: model.isThinking ? "busy" : "ready", accent: model.isThinking ? AppTheme.amber : AppTheme.terminalGreen)

            Button {
                model.isSettingsVisible.toggle()
            } label: {
                Text("Settings")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .frame(width: 82)
            }
            .buttonStyle(TerminalButtonStyle(accent: AppTheme.codexBlue))
        }
        .padding(14)
        .background(AppTheme.panelRaised)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.border)
        )
        .padding(.bottom, 10)
    }

    private var sourceControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                TextField("Paste a GitHub repo URL, including private repos your local Git can clone", text: $model.repoURL)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(AppTheme.text)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(AppTheme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(AppTheme.border))

                TextField("branch/tag", text: $model.repoRef)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(AppTheme.text)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .frame(width: 120)
                    .background(AppTheme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(AppTheme.border))

                Button {
                    model.loadRepo()
                } label: {
                    Text(model.isLoadingRepo ? "Loading" : "Load Repo")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .frame(width: 92)
                }
                .buttonStyle(TerminalButtonStyle(accent: AppTheme.codexBlue))
                .disabled(model.isLoadingRepo)

                Button {
                    model.chooseLocalFolder()
                } label: {
                    Text("Folder")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .frame(width: 72)
                }
                .buttonStyle(TerminalButtonStyle(accent: AppTheme.terminalGreen))
                .disabled(model.isLoadingRepo)

                Button {
                    model.clearSource()
                } label: {
                    Text("Clear")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .frame(width: 64)
                }
                .buttonStyle(TerminalButtonStyle(accent: AppTheme.error))
                .disabled(model.sourceName == nil)
            }

            HStack(spacing: 8) {
                Text("source")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.terminalGreen)
                Text(model.repoStatus)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button {
                    model.isContextVisible.toggle()
                } label: {
                    Text(model.isContextVisible ? "Hide Context" : "Show Context")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .frame(width: 112)
                }
                .buttonStyle(TerminalButtonStyle(accent: AppTheme.amber))
            }
        }
        .padding(12)
        .background(AppTheme.panel)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)
        }
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("settings")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.codexBlue)
                Text(model.status)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppTheme.muted)
                Spacer()
                Button {
                    model.reloadModels()
                } label: {
                    Text("Refresh Models")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .frame(width: 122)
                }
                .buttonStyle(TerminalButtonStyle(accent: AppTheme.codexBlue))
                Button {
                    model.saveSettings()
                } label: {
                    Text("Save")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .frame(width: 58)
                }
                .buttonStyle(TerminalButtonStyle(accent: AppTheme.terminalGreen))
            }

            HStack(spacing: 10) {
                if model.availableModels.isEmpty {
                    settingTextField("model", text: $model.settings.model)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("model")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppTheme.muted)
                        Picker("", selection: $model.settings.model) {
                            ForEach(model.availableModels, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 210)
                    }
                }
                settingTextField("ollama", text: $model.settings.ollamaBaseURL)
                settingStepper("timeout", value: $model.settings.timeoutSeconds, range: 30...1800, step: 30, suffix: "s")
                settingStepper("tokens", value: $model.settings.numPredict, range: 64...4096, step: 64, suffix: "")
            }
        }
        .padding(12)
        .background(AppTheme.panelRaised)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)
        }
    }

    private var contextPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("context")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.amber)
                Text(model.sourceSummary)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("indexed files")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.muted)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(model.indexedFiles.prefix(18), id: \.path) { file in
                                Text(file.path)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(AppTheme.text.opacity(0.82))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            if model.indexedFiles.count > 18 {
                                Text("+ \(model.indexedFiles.count - 18) more")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(AppTheme.muted)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 82)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text("last prompt snippets")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.muted)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 3) {
                            if let selection = model.lastSelection, !selection.snippets.isEmpty {
                                ForEach(selection.snippets) { snippet in
                                    Text("\(snippet.path) #\(snippet.chunkIndex + 1) score \(snippet.score)")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(AppTheme.text.opacity(0.82))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Text("\(selection.promptCharacterCount) context chars")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(AppTheme.muted)
                            } else {
                                Text("Ask a source question to see exactly what Gemma received.")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(AppTheme.muted)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 82)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(AppTheme.panel)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)
        }
    }

    private var messages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(model.messages) { message in
                        messageView(message)
                            .id(message.id)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(AppTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border))
            .onChange(of: model.messages.count) {
                if let last = model.messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private func messageView(_ message: ChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                Text(promptGlyph(for: message))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(accentColor(for: message))
                Text(message.speaker)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(accentColor(for: message))
            }
            Text(message.text.isEmpty ? "..." : message.text)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(AppTheme.text)
                .textSelection(.enabled)
        }
        .padding(13)
        .frame(maxWidth: 720, alignment: .leading)
        .background(backgroundColor(for: message))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(accentColor(for: message).opacity(0.35)))
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
    }

    private var composer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("prompt")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.terminalGreen)
                Text(model.status)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppTheme.muted)
                Spacer()
            }

            HStack(alignment: .bottom, spacing: 12) {
                TextEditor(text: $model.prompt)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(AppTheme.text)
                    .scrollContentBackground(.hidden)
                    .background(AppTheme.background)
                    .frame(minHeight: 76, maxHeight: 132)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border))

                Button {
                    if model.isThinking {
                        model.stopGenerating()
                    } else {
                        model.send()
                    }
                } label: {
                    Text(model.isThinking ? "STOP" : "SEND")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .frame(width: 76)
                }
                .buttonStyle(TerminalButtonStyle(accent: model.isThinking ? AppTheme.error : AppTheme.amber))
                .keyboardShortcut(.return, modifiers: [.command])
            }
        }
        .padding(14)
        .background(AppTheme.panelRaised)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border))
        .padding(.top, 10)
    }

    private func settingTextField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.muted)
            TextField(label, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(AppTheme.text)
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background(AppTheme.background)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(AppTheme.border))
        }
    }

    private func settingStepper(_ label: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.muted)
            Stepper(value: value, in: range, step: step) {
                Text("\(value.wrappedValue)\(suffix)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(AppTheme.text)
                    .frame(width: 78, alignment: .leading)
            }
        }
        .frame(width: 124)
    }

    private func backgroundColor(for message: ChatMessage) -> Color {
        if message.isError {
            return AppTheme.error.opacity(0.16)
        }
        if message.speaker == "Codex" {
            return AppTheme.codexBlue.opacity(0.15)
        }
        if message.isUser {
            return AppTheme.terminalGreen.opacity(0.12)
        }
        return AppTheme.panelRaised
    }

    private func accentColor(for message: ChatMessage) -> Color {
        if message.isError {
            return AppTheme.error
        }
        if message.speaker == "Codex" {
            return AppTheme.codexBlue
        }
        if message.isUser {
            return AppTheme.terminalGreen
        }
        return AppTheme.amber
    }

    private func promptGlyph(for message: ChatMessage) -> String {
        if message.isError {
            return "!"
        }
        if message.speaker == "Codex" {
            return "C"
        }
        if message.isUser {
            return "$"
        }
        return "G"
    }
}

