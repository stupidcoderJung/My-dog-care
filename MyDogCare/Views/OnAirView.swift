import SwiftUI
import AVFoundation

struct OnAirView: View {
    @StateObject private var cameraManager = CameraManager()
    @EnvironmentObject private var visionClient: VisionClient
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Dog.createdAt, ascending: false)],
        animation: .default
    )
    private var dogs: FetchedResults<Dog>
    
    @State private var capturedImages: [UIImage] = []
    @State private var analysisResult: String = ""
    @State private var debugTurns: [DebugTurn] = []
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // 1. Camera Feed (Top Half)
                ZStack {
                    if cameraManager.permissionGranted {
                        if let currentFrame = cameraManager.currentFrame {
                            Image(decorative: currentFrame, scale: 1.0, orientation: .up)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .clipped()
                        } else {
                            Color.black
                            ProgressView()
                                .tint(.white)
                        }
                    } else {
                        Color.black
                        Text("Camera permission required")
                            .foregroundStyle(.white)
                    }
                }
                .frame(height: UIScreen.main.bounds.height * 0.45)
                .overlay(alignment: .topLeading) {
                    if isAnalyzing {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)
                            Text("LIVE")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.6))
                        .cornerRadius(4)
                        .padding(16)
                    }
                }
                
                // 2. Image Strip (Thin)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(0..<capturedImages.count, id: \.self) { index in
                            Image(uiImage: capturedImages[index])
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .frame(height: 80)
                .background(Color(.systemGray6))
                
                // 3. Analysis Result & Debug (Bottom)
                TabView {
                    // Page 1: Result
                    ResultView(analysisResult: analysisResult, errorMessage: errorMessage)
                        .tag(0)
                    
                    // Page 2: Debug Prompt
                    PromptDebugView(debugTurns: debugTurns)
                        .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .background(Color(.systemBackground))
            }
            .edgesIgnoringSafeArea(.top)
            
            // Analyze Button - Floating Action Button (FAB) in bottom-right
            VStack {
                Spacer()
                    .frame(height: UIScreen.main.bounds.height * 0.45 - 100)
                
                HStack {
                    Spacer()
                    
                    Button(action: toggleAnalysis) {
                        ZStack {
                            // Pulsing animation when analyzing
                            if isAnalyzing {
                                Circle()
                                    .fill(Color.red.opacity(0.3))
                                    .frame(width: 72, height: 72)
                                    .scaleEffect(1.2)
                                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnalyzing)
                            }
                            
                            // Main button
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: isAnalyzing ? [Color.red, Color.red.opacity(0.8)] : [Color.blue, Color.blue.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 64, height: 64)
                                .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
                            
                            // Icon
                            if isAnalyzing {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(.white)
                                    .frame(width: 24, height: 24)
                            } else {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundStyle(.white)
                                    .offset(x: 2) // Center the play icon visually
                            }
                        }
                    }
                    .disabled(!cameraManager.permissionGranted)
                    .opacity(!cameraManager.permissionGranted ? 0.5 : 1.0)
                    .padding(.trailing, 20)
                }
                
                Spacer()
            }
        }
        .onAppear {
            cameraManager.start()
        }
        .onDisappear {
            cameraManager.stop()
            stopAnalysis()
        }
    }
    
    private func toggleAnalysis() {
        if isAnalyzing {
            stopAnalysis()
        } else {
            startAnalysisLoop()
        }
    }
    
    private func stopAnalysis() {
        isAnalyzing = false
    }
    
    private func startAnalysisLoop() {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        errorMessage = nil
        
        Task {
            while isAnalyzing {
                await performAnalysisStep()
                
                if isAnalyzing {
                    // Wait for 1 second before next analysis to avoid rate limits
                    try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
                }
            }
        }
    }
    
    private func performAnalysisStep() async {
        // Capture 5 frames with 0.2s interval
        let frames = await cameraManager.captureBurst(count: 5, interval: 0.2)
        
        await MainActor.run {
            self.capturedImages = frames
        }
        
        guard !frames.isEmpty else {
            await MainActor.run {
                self.errorMessage = "Failed to capture images"
                // Don't stop the loop on capture failure, just retry
            }
            return
        }
        
        do {
            // Convert FetchedResults to Array for the async call
            let dogList = dogs.map { $0 }
            let result = try await visionClient.analyzeStream(images: frames, dogs: dogList)
            
            await MainActor.run {
                // Format VisionResponse to String for display
                let response = result.response
                var formattedResult = "Time: \(response.timestamp)\n\n"
                
                if !response.dogs.isEmpty {
                    formattedResult += "Dogs:\n"
                    for dog in response.dogs {
                        formattedResult += "- \(dog.name) (\(Int(dog.confidence * 100))%)\n"
                        formattedResult += "  Action: \(dog.action)\n"
                        formattedResult += "  Posture: \(dog.posture)\n"
                        formattedResult += "  Emotion: \(dog.emotion)\n"
                        if !dog.health_signals.isEmpty {
                            formattedResult += "  Health: \(dog.health_signals.joined(separator: ", "))\n"
                        }
                        formattedResult += "\n"
                    }
                }
                
                formattedResult += "Environment:\n"
                formattedResult += "Location: \(response.environment.location)\n"
                if !response.environment.objects.isEmpty {
                    formattedResult += "Objects: \(response.environment.objects.joined(separator: ", "))"
                }
                
                self.analysisResult = formattedResult
                self.debugTurns = result.debugTurns
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                // Don't stop the loop on API error, just retry
            }
        }
    }
}

struct ResultView: View {
    let analysisResult: String
    let errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let error = errorMessage {
                    Text("Error")
                        .font(.headline)
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !analysisResult.isEmpty {
                    Text("AI Analysis Result")
                        .font(.headline)
                        .foregroundStyle(.tint)
                    
                    Text(analysisResult)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                } else {
                    Text("Ready to analyze")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                }
            }
            .padding()
        }
    }
}

struct PromptDebugView: View {
    let debugTurns: [DebugTurn]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Conversation History")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                ForEach(debugTurns) { turn in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(turn.role)
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(roleColor(for: turn.role).opacity(0.1))
                            .cornerRadius(4)
                        
                        if !turn.images.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(0..<turn.images.count, id: \.self) { index in
                                        Image(uiImage: turn.images[index])
                                            .resizable()
                                            .scaledToFill()
                                            .frame(height: 100)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                        }
                        
                        Text(turn.content)
                            .font(.caption.monospaced())
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                    }
                    .padding(.bottom, 8)
                    
                    Divider()
                }
            }
            .padding()
        }
    }
    
    private func roleColor(for role: String) -> Color {
        switch role.lowercased() {
        case "system": return .purple
        case "user": return .blue
        case "assistant": return .green
        default: return .gray
        }
    }
}

#Preview {
    OnAirView()
        .environmentObject(VisionClient())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
