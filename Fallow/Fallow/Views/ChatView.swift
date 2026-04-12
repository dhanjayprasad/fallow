// ChatView.swift
// Local chat interface against the KwaaiNet OpenAI-compatible API.
// Part of Fallow. MIT licence.

import SwiftUI
import OSLog

/// A single chat message.
struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    var content: String
    let timestamp = Date()

    enum Role: String {
        case user
        case assistant
    }
}

struct ChatView: View {
    var appState: AppState
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isStreaming = false
    @State private var streamTask: Task<Void, Never>?
    @State private var scrollTrigger = 0

    private let creditsPerMessage: Double = 0.5

    private static let chatSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Chat")
                    .font(.headline)
                Spacer()
                Text("\(String(format: "%.0f", appState.creditLedger.balance)) credits")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Clear", systemImage: "trash") {
                    messages.removeAll()
                }
                .buttonStyle(.borderless)
                .labelStyle(.iconOnly)
            }
            .padding()

            Divider()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if messages.isEmpty {
                            emptyState
                        }
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: scrollTrigger) {
                    if let last = messages.last {
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input
            HStack {
                TextField("Type a message...", text: $inputText)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        guard !isStreaming else { return }
                        streamTask = Task { await send() }
                    }
                    .disabled(isStreaming)

                Button {
                    if isStreaming {
                        streamTask?.cancel()
                        isStreaming = false
                    } else {
                        streamTask = Task { await send() }
                    }
                } label: {
                    Image(systemName: isStreaming
                        ? "stop.fill" : "arrow.up.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
                .disabled(
                    inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && !isStreaming
                )
            }
            .padding()
        }
        .frame(minWidth: 400, minHeight: 500)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("Start a conversation")
                .foregroundStyle(.secondary)
            if !appState.kwaaiNetManager.status.isRunning {
                Text("KwaaiNet node is not running. Start the node to chat.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Send

    private func send() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }

        guard appState.creditLedger.balance >= creditsPerMessage else {
            messages.append(ChatMessage(
                role: .assistant,
                content: "Not enough credits. Contribute compute to earn more."
            ))
            return
        }

        messages.append(ChatMessage(role: .user, content: text))
        inputText = ""
        isStreaming = true
        let assistantMessage = ChatMessage(role: .assistant, content: "")
        messages.append(assistantMessage)
        let messageId = assistantMessage.id

        defer { isStreaming = false }

        do {
            let apiMessages = messages.dropLast().map {
                ["role": $0.role.rawValue, "content": $0.content]
            }
            let modelName = appState.kwaaiNetManager.status.modelName ?? "default"
            let body: [String: Any] = [
                "model": modelName,
                "messages": apiMessages,
                "stream": true,
            ]

            guard let url = URL(string: "http://localhost:8000/v1/chat/completions") else {
                updateMessage(id: messageId, content: "Error: invalid API URL")
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (bytes, response) = try await Self.chatSession.bytes(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                updateMessage(id: messageId, content: "Error: API not available. Is the node running?")
                return
            }

            for try await line in bytes.lines {
                guard !Task.isCancelled else { break }
                guard line.hasPrefix("data: ") else { continue }
                let data = String(line.dropFirst(6))
                if data == "[DONE]" { break }

                guard let jsonData = data.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let delta = choices.first?["delta"] as? [String: Any],
                      let content = delta["content"] as? String
                else { continue }

                appendToMessage(id: messageId, content: content)
            }

            // Only charge if we received actual content
            if let idx = messages.firstIndex(where: { $0.id == messageId }),
               !messages[idx].content.isEmpty {
                appState.creditLedger.spendCredits(creditsPerMessage)
            }
        } catch {
            if let idx = messages.firstIndex(where: { $0.id == messageId }),
               messages[idx].content.isEmpty {
                messages[idx].content = "Error: \(error.localizedDescription)"
            }
            Logger.chat.error("Chat stream error: \(error)")
        }
    }

    private func updateMessage(id: UUID, content: String) {
        guard let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[idx].content = content
    }

    private func appendToMessage(id: UUID, content: String) {
        guard let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[idx].content += content
        scrollTrigger += 1
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }

            Text(message.content.isEmpty ? " " : message.content)
                .padding(10)
                .background(
                    message.role == .user
                        ? Color.accentColor.opacity(0.15)
                        : Color.secondary.opacity(0.1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .textSelection(.enabled)

            if message.role == .assistant { Spacer(minLength: 60) }
        }
    }
}
