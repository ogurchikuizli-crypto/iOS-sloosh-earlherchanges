import SwiftUI

// MARK: - Watch Party Chat Overlay View

struct WatchPartyChatOverlayView: View {
    @ObservedObject var watchPartyRepo = WatchPartyRepository.shared
    let currentTime: Double
    let onSeek: (Double) -> Void
    let onClose: () -> Void

    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.green)

                    Text("Чат просмотра")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }

                Spacer()

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Закрыть чат")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.black.opacity(0.2))

            Divider()
                .background(Color.white.opacity(0.12))

            // Messages List
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if watchPartyRepo.chatMessages.isEmpty {
                            VStack(spacing: 6) {
                                Image(systemName: "bubble.middle.bottom")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white.opacity(0.4))
                                    .padding(.top, 30)

                                Text("Напишите сообщение или таймкод")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))

                                Text("Таймкоды вида 12:34 кликабельны")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.35))
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
                        } else {
                            ForEach(watchPartyRepo.chatMessages) { msg in
                                chatBubble(for: msg)
                                    .id(msg.id)
                            }
                        }
                    }
                    .padding(14)
                }
                .onChange(of: watchPartyRepo.chatMessages.count) { _, _ in
                    if let last = watchPartyRepo.chatMessages.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()
                .background(Color.white.opacity(0.12))

            // Input Bar
            VStack(spacing: 8) {
                // Quick Timecode Chip
                HStack {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        let tc = WatchPartyTimecode.format(currentTime)
                        if inputText.isEmpty {
                            inputText = "\(tc) "
                        } else {
                            inputText += " \(tc) "
                        }
                        isInputFocused = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.badge.plus")
                                .font(.system(size: 11, weight: .semibold))
                            Text(WatchPartyTimecode.format(currentTime))
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        }
                        .foregroundColor(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.15))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)

                // Text Input & Send
                HStack(spacing: 10) {
                    TextField("Сообщение или таймкод...", text: $inputText)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .focused($isInputFocused)
                        .submitLabel(.send)
                        .onSubmit {
                            sendMessage()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 18))

                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.white.opacity(0.3) : Color.green)
                    }
                    .buttonStyle(.plain)
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
            .background(Color.black.opacity(0.25))
        }
        .frame(width: 320, height: 380)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.1, green: 0.1, blue: 0.12).opacity(0.88))
        )
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 10)
    }

    // MARK: - Chat Bubble

    private func chatBubble(for msg: WatchPartyChatMessage) -> some View {
        let isMe = msg.uid == watchPartyRepo.currentUserId
        let segments = WatchPartyTimecode.segments(in: msg.text)

        return HStack {
            if isMe { Spacer(minLength: 30) }

            VStack(alignment: isMe ? .trailing : .leading, spacing: 3) {
                if !isMe && !msg.name.isEmpty {
                    Text(msg.name)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.green)
                }

                // Bubble body with timecodes
                renderSegments(segments, isMe: isMe)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        isMe
                            ? Color.green.opacity(0.25)
                            : Color.white.opacity(0.12)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                isMe ? Color.green.opacity(0.4) : Color.white.opacity(0.15),
                                lineWidth: 1
                            )
                    )
            }

            if !isMe { Spacer(minLength: 30) }
        }
    }

    // MARK: - Segments Renderer

    @ViewBuilder
    private func renderSegments(_ segments: [WatchPartyTimecodeSegment], isMe: Bool) -> some View {
        let hasTimecode = segments.contains { seg in
            if case .timecode = seg { return true }
            return false
        }

        if !hasTimecode {
            Text(segments.map { seg -> String in
                if case .text(let t) = seg { return t }
                return ""
            }.joined())
            .font(.system(size: 13))
            .foregroundColor(.white)
        } else {
            // Flow of segments
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    switch segment {
                    case .text(let txt):
                        let trimmed = txt.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            Text(txt)
                                .font(.system(size: 13))
                                .foregroundColor(.white)
                        }
                    case .timecode(let token, let seconds):
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            onSeek(seconds)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 9))
                                Text(token)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.4))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.green, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        watchPartyRepo.sendChatMessage(text: trimmed)
        inputText = ""
    }
}
