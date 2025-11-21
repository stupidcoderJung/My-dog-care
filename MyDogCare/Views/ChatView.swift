import SwiftUI

struct ChatView: View {
    @StateObject private var chatService = ChatService()
    @State private var inputText: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Chat History
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            ForEach(chatService.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                            
                            if chatService.isProcessing {
                                HStack(spacing: 12) {
                                    AssistantAvatar()
                                    
                                    HStack(spacing: 4) {
                                        ForEach(0..<3) { index in
                                            Circle()
                                                .fill(Color.gray.opacity(0.5))
                                                .frame(width: 6, height: 6)
                                                .scaleEffect(1.0)
                                                .animation(
                                                    .easeInOut(duration: 0.6)
                                                    .repeatForever()
                                                    .delay(Double(index) * 0.2),
                                                    value: true
                                                )
                                        }
                                    }
                                    .padding(12)
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                    
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .id("processing")
                            }
                        }
                        .padding(.vertical)
                    }
                    .onTapGesture {
                        isFocused = false
                    }
                    .onChange(of: chatService.messages) { _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: chatService.isProcessing) { isProcessing in
                        if isProcessing {
                            withAnimation {
                                proxy.scrollTo("processing", anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Input Area
                HStack(spacing: 10) {
                    TextField("메시지를 입력하세요...", text: $inputText)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .clipShape(Capsule())
                        .focused($isFocused)
                        .submitLabel(.send)
                        .onSubmit(sendMessage)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(inputText.isEmpty ? Color.gray.opacity(0.5) : Color.blue)
                            )
                            .shadow(color: .blue.opacity(0.3), radius: 3, x: 0, y: 2)
                    }
                    .disabled(inputText.isEmpty || chatService.isProcessing)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
            .navigationTitle("AI Chat")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemBackground))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: chatService.clearChat) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }
    
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        chatService.sendMessage(inputText)
        inputText = ""
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastMessage = chatService.messages.last else { return }
        withAnimation {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if message.role == .user {
                Spacer()
            } else {
                AssistantAvatar()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading) {
                if message.type == .graph {
                    GraphWebView(htmlContent: message.content)
                        .frame(height: 300)
                        .frame(maxWidth: 300)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                } else {
                    Text(message.content)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            message.role == .user ?
                            AnyShapeStyle(LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)) :
                                AnyShapeStyle(Color(.systemGray6))
                        )
                        .foregroundColor(message.role == .user ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                }
            }
            
            if message.role == .assistant {
                Spacer()
            }
        }
        .padding(.horizontal)
    }
}

struct AssistantAvatar: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 36, height: 36)
            
            Image(systemName: "pawprint.fill")
                .foregroundColor(.white)
                .font(.system(size: 16))
        }
        .shadow(color: .purple.opacity(0.3), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    NavigationView {
        ChatView()
    }
}
