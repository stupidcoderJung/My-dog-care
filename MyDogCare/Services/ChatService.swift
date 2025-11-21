import Foundation
import Combine

class ChatService: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isProcessing: Bool = false
    
    init() {
        // Initial welcome message
        messages.append(ChatMessage(role: .assistant, content: "우리 강아지에 대하여 무엇이 궁금하시나요?"))
    }
    
    func sendMessage(_ text: String) {
        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        
        isProcessing = true
        
        // Mock response delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.generateMockResponse(for: text)
            self?.isProcessing = false
        }
    }
    
    func clearChat() {
        messages.removeAll()
        messages.append(ChatMessage(role: .assistant, content: "우리 강아지에 대하여 무엇이 궁금하시나요?"))
    }
    
    private func generateMockResponse(for text: String) {
        // Simple keyword detection for demo purposes
        if text.contains("그래프") || text.contains("graph") || text.contains("차트") {
            let graphContent = """
            <html>
            <head>
            <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
            <style>body { margin: 0; padding: 0; display: flex; justify-content: center; align-items: center; height: 100vh; background-color: #f4f4f4; }</style>
            </head>
            <body>
            <div style="width: 90%; height: 90%;">
                <canvas id="myChart"></canvas>
            </div>
            <script>
            const ctx = document.getElementById('myChart').getContext('2d');
            new Chart(ctx, {
                type: 'line',
                data: {
                    labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
                    datasets: [{
                        label: 'Activity Level',
                        data: [12, 19, 3, 5, 2, 3, 15],
                        borderColor: 'rgb(75, 192, 192)',
                        tension: 0.1
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false
                }
            });
            </script>
            </body>
            </html>
            """
            let response = ChatMessage(role: .assistant, content: graphContent, type: .graph)
            messages.append(response)
        } else {
            let response = ChatMessage(role: .assistant, content: "흥미로운 질문이네요! 더 자세히 말씀해 주시겠어요? (그래프를 보려면 '그래프 보여줘'라고 해보세요)")
            messages.append(response)
        }
    }
}
