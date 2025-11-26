import SwiftUI
import AVFoundation

struct OnAirView: View {
    @EnvironmentObject private var visionService: VisionService
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
    
    // Event Uploader (initialized with localhost for testing)
//    @StateObject private var eventUploader = EventUploader(baseURL: "http://localhost:8001")
    @StateObject private var eventUploader = EventUploader(baseURL: "http://192.168.0.77:8001")
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // 1. Camera Feed (Top Half)
                ZStack {
                    if let currentFrame = visionService.currentFrame {
                        Image(decorative: currentFrame, scale: 1.0, orientation: .up)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                            .overlay {
                                DetectionOverlay(
                                    detectedDogs: visionService.detectedDogs,
                                    imageSize: CGSize(width: CGFloat(currentFrame.width), height: CGFloat(currentFrame.height))
                                )
                            }
                    } else {
                        Color.black
                        ProgressView()
                            .tint(.white)
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
                .overlay(alignment: .topTrailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(String(format: "FPS: %.1f", visionService.fps))
                            .font(.caption.monospaced())
                            .foregroundColor(.green)
                        
                        if let packet = visionService.currentPacket {
                            PacketDebugView(packet: packet)
                        }
                    }
                    .padding(6)
                    .background(.black.opacity(0.6))
                    .cornerRadius(4)
                    .padding(8)
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
                    .padding(.trailing, 20)
                }
                
                Spacer()
            }
        }
        .onAppear {
            visionService.startProcessing()
            visionService.refreshKnownDogs()
            
            // Retry any pending uploads from previous sessions
            Task {
                await eventUploader.retryPendingUploads()
            }
        }
        .onDisappear {
            visionService.stopProcessing()
            stopAnalysis()
        }
    }
    
    private func toggleAnalysis() {
        print("🔘 OnAirView: toggleAnalysis() called. isAnalyzing = \(isAnalyzing)")
        if isAnalyzing {
            stopAnalysis()
        } else {
            startAnalysisLoop()
        }
    }
    
    private func stopAnalysis() {
        print("🛑 OnAirView: stopAnalysis() called")
        isAnalyzing = false
    }
    
    private func startAnalysisLoop() {
        guard !isAnalyzing else {
            print("⚠️ OnAirView: Already analyzing, skipping")
            return
        }
        print("▶️ OnAirView: startAnalysisLoop() - Setting isAnalyzing to true")
        isAnalyzing = true
        errorMessage = nil
        
        Task {
            print("🔄 OnAirView: Task started, entering while loop")
            while isAnalyzing {
                print("⚡️ OnAirView: Calling performAnalysisStep()")
                await performAnalysisStep()
                
                if isAnalyzing {
                    // Wait for 1 second before next analysis to avoid rate limits
                    print("⏳ OnAirView: Sleeping for 1 second...")
                    try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
                }
            }
            print("⏹️ OnAirView: Exited while loop")
        }
    }
    
    private func performAnalysisStep() async {
        // Manual frame capture removed - VisionService now handles buffering

        do {
            // Convert FetchedResults to Array for the async call
            let dogList = dogs.map { $0 }
            
            print("🧠 OnAirView: Calling visionService.analyzeWithVLM")
            // Use VisionService to analyze with VLM (uses buffered frames)
            let (response, taggedImages, debugTurns) = try await visionService.analyzeWithVLM(
                knownDogs: dogList
            )
            print("✅ OnAirView: Analysis successful. Timestamp: \(response.timestamp)")
            
            await MainActor.run {
                self.capturedImages = taggedImages // Update UI with tagged images
                self.debugTurns = debugTurns // Update debug history
                
                // Add generated packet to EventUploader
                if let packet = visionService.currentPacket {
                    eventUploader.addPacket(packet)
                }
                
                // Format VisionResponse to String for display
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
                        if let notes = dog.notes, !notes.isEmpty {
                            formattedResult += "  Notes: \(notes)\n"
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
                // self.debugTurns = result.debugTurns // VisionService.analyzeWithVLM returns VisionResponse, not tuple with debugTurns yet.
                // We might need to update VisionService to return debugTurns if we want them.
                // For now, let's ignore debugTurns or fetch them if possible.
                // The prompt said "VisionService.analyzeWithVLM returns VisionResponse".
                // So debugTurns are lost unless we update VisionService.
                // I will comment out debugTurns for now.
            }
        } catch {
            print("❌ OnAirView: Analysis failed: \(error)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
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

struct PacketDebugView: View {
    let packet: DeviceStatePacket
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("PKT: \(timeString(from: packet.timestamp))")
            Text("DOGS: \(packet.dogs.count)")
            Text("RELS: \(packet.relations?.count ?? 0)")
            if let env = packet.environment {
                Text("CROWD: \(env.crowding ?? 0)")
            }
            Text("SID: \(packet.sessionId.prefix(4))")
        }
        .font(.system(size: 10, design: .monospaced))
        .foregroundColor(.white)
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.S"
        return formatter.string(from: date)
    }
}

#Preview {
    OnAirView()
        .environmentObject(VisionClient())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
