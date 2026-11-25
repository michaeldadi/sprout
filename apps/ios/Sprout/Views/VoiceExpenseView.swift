import SwiftUI
import Speech
import AVFoundation

struct VoiceExpenseView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var amount: String = ""
    @State private var category: String = ""
    @State private var merchant: String = ""
    @State private var notes: String = ""
    @State private var isListening = false
    @State private var showingPermissionAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.2, green: 0.8, blue: 0.4),
                                    Color(red: 0.1, green: 0.6, blue: 0.3)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Voice Expense Entry")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Say something like: \"I spent $12.50 at Starbucks for coffee\"")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Voice input area
                VStack(spacing: 16) {
                    // Recognized text display
                    ScrollView {
                        Text(speechRecognizer.transcript.isEmpty ? "Tap the microphone and start speaking..." : speechRecognizer.transcript)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .frame(maxHeight: 120)
                    
                    // Microphone button
                    Button(action: toggleListening) {
                        HStack {
                            Image(systemName: isListening ? "mic.fill" : "mic")
                                .font(.title2)
                            Text(isListening ? "Stop Listening" : "Start Voice Entry")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isListening ? Color.red : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!speechRecognizer.isAvailable)
                }
                
                // Extracted information
                if !amount.isEmpty || !category.isEmpty || !merchant.isEmpty {
                    VStack(spacing: 12) {
                        Text("Extracted Information")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        if !amount.isEmpty {
                            HStack {
                                Text("Amount:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(amount)
                            }
                        }
                        
                        if !merchant.isEmpty {
                            HStack {
                                Text("Merchant:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(merchant)
                            }
                        }
                        
                        if !category.isEmpty {
                            HStack {
                                Text("Category:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(category)
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 16) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)
                    
                    Button("Save Expense") {
                        saveExpense()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled(amount.isEmpty)
                }
            }
            .padding()
            .navigationTitle("Voice Entry")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .onChange(of: speechRecognizer.transcript) { _, newTranscript in
                parseExpenseFromText(newTranscript)
            }
            .onAppear {
                speechRecognizer.requestPermission()
            }
            .alert("Speech Recognition Permission", isPresented: $showingPermissionAlert) {
                Button("Settings") {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please enable Speech Recognition in Settings to use voice expense entry.")
            }
        }
    }
    
    private func toggleListening() {
        if isListening {
            speechRecognizer.stopTranscribing()
        } else {
            if speechRecognizer.isAvailable {
                speechRecognizer.startTranscribing()
            } else {
                showingPermissionAlert = true
                return
            }
        }
        isListening.toggle()
    }
    
    private func parseExpenseFromText(_ text: String) {
        // Simple parsing logic for demo - in production you'd use more sophisticated NLP
        let lowercased = text.lowercased()
        
        let candidates = ExpenseDraft.explicitAmounts(in: text)
        amount = candidates.count == 1 ? candidates[0] : ""

        // Extract merchant (common patterns)
        let merchantKeywords = ["at ", "from ", "to "]
        for keyword in merchantKeywords {
            if let range = lowercased.range(of: keyword) {
                let afterKeyword = lowercased[range.upperBound...]
                let words = afterKeyword.split(separator: " ")
                if let firstWord = words.first {
                    merchant = String(firstWord).capitalized
                    break
                }
            }
        }
        
        // Extract category (simple keyword matching)
        let categoryKeywords = [
            "coffee": "Food & Dining",
            "lunch": "Food & Dining",
            "dinner": "Food & Dining",
            "breakfast": "Food & Dining",
            "gas": "Transportation",
            "fuel": "Transportation",
            "uber": "Transportation",
            "grocery": "Groceries",
            "groceries": "Groceries"
        ]
        
        for (keyword, cat) in categoryKeywords {
            if lowercased.contains(keyword) {
                category = cat
                break
            }
        }
    }
    
    private func saveExpense() {
        // Here you would save to your data model
        // For now, just dismiss
        presentationMode.wrappedValue.dismiss()
    }
}

@MainActor
class SpeechRecognizer: ObservableObject {
    @Published var transcript = ""
    @Published var isAvailable = false
    
    private var audioEngine = AVAudioEngine()
    private var speechRecognizer = SFSpeechRecognizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var hasInstalledTap = false
    
    init() {
        checkAvailability()
    }
    
    private func checkAvailability() {
        isAvailable = SFSpeechRecognizer.authorizationStatus() == .authorized && speechRecognizer?.isAvailable == true
    }
    
    func requestPermission() { Task { isAvailable = await requestAccess() } }

    func requestAccess() async -> Bool {
        let status = await withCheckedContinuation { continuation in SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) } }
        guard status == .authorized else { isAvailable = false; return false }
        let microphone = await AVAudioApplication.requestRecordPermission()
        isAvailable = microphone && speechRecognizer?.isAvailable == true
        return isAvailable
    }

    func startTranscribing() {
        stopTranscribing()
        guard isAvailable, let speechRecognizer, speechRecognizer.isAvailable else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.record,mode: .measurement,options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = speechRecognizer.supportsOnDeviceRecognition
            recognitionRequest = request
            recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let result { self.transcript = result.bestTranscription.formattedString }
                    if error != nil || result?.isFinal == true { self.stopTranscribing() }
                }
            }
            let input = audioEngine.inputNode
            input.installTap(onBus: 0,bufferSize: 1024,format: input.outputFormat(forBus: 0)) { buffer,_ in request.append(buffer) }
            hasInstalledTap = true
            audioEngine.prepare(); try audioEngine.start()
        } catch { stopTranscribing(); isAvailable = false }
    }

    func stopTranscribing() {
        audioEngine.stop()
        if hasInstalledTap { audioEngine.inputNode.removeTap(onBus: 0); hasInstalledTap = false }
        recognitionRequest?.endAudio(); recognitionRequest = nil
        let task = recognitionTask; recognitionTask = nil; task?.cancel()
        try? AVAudioSession.sharedInstance().setActive(false,options: .notifyOthersOnDeactivation)
    }

}

#Preview {
    VoiceExpenseView()
}
