import SwiftUI
import UIKit

// MARK: - Heart Animation View using CABasicAnimation
struct HeartBeatView: UIViewRepresentable {
    let trigger: Int
    
    class HeartView: UIView {
        private let imageView = UIImageView()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            setupImageView()
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            setupImageView()
        }
        
        private func setupImageView() {
            let config = UIImage.SymbolConfiguration(pointSize: 40, weight: .regular)
            imageView.image = UIImage(systemName: "heart.fill", withConfiguration: config)
            imageView.tintColor = .systemGreen
            imageView.contentMode = .scaleAspectFit
            
            addSubview(imageView)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
                imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
                imageView.widthAnchor.constraint(equalTo: widthAnchor),
                imageView.heightAnchor.constraint(equalTo: heightAnchor)
            ])
        }
        
        func performHeartBeat() {
            let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
            pulseAnimation.toValue = NSNumber(value: 1.5)
            pulseAnimation.fromValue = NSNumber(value: 1.0)
            pulseAnimation.duration = 0.1
            pulseAnimation.repeatCount = 1
            pulseAnimation.autoreverses = true
            pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeIn)
            
            imageView.layer.add(pulseAnimation, forKey: "scale")
        }
    }
    
    func makeUIView(context: Context) -> HeartView {
        return HeartView()
    }
    
    func updateUIView(_ uiView: HeartView, context: Context) {
        uiView.performHeartBeat()
    }
}

// MARK: - Main View
struct RunnerHomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    let environment: AppEnvironment
    @StateObject private var model: RunnerViewModel
    @State private var showingSessions = false
    @State private var showingDevices = false
    @State private var showingSettings = false

    init(environment: AppEnvironment) {
        self.environment = environment
        _model = StateObject(wrappedValue: RunnerViewModel(environment: environment))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if model.settings.audioEnabled {
                    HStack {
                        Spacer()
                        Text(model.settings.heartRateSpeakIntervalSeconds == 0
                             ? "Heart rate cue on every received sample"
                             : "Next heart rate cue in: \(model.secondsUntilNextAnnouncement)s")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                model.announceWithTimeRemaining()
                            }
                        Spacer()
                    }
                    .padding(.top, -16)
                }
                
                connectionStatusSection
                sessionPickerSection
                heartRateDisplaySection
                startSessionButtonSection
                cueMessageSection
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Fartlek")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        model.toggleAudio()
                    }) {
                        Image(systemName: model.settings.audioEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .task {
            await model.loadSettings()
        }
        .onAppear {
            model.updateHeartRateAvailability()
            environment.heartRateService.checkForExistingConnection()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.updateHeartRateAvailability()
                environment.heartRateService.checkForExistingConnection()
            }
        }
        .onReceive(environment.$selectedSession) { session in
            if let session { model.selectSession(session) }
        }
        .sheet(isPresented: $showingSessions) {
            SessionPickerSheet(environment: environment, model: model)
        }
        .sheet(isPresented: $showingDevices) {
            HeartRateMonitorView(model: model)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsHomeView(settings: Binding(
                get: { model.settings },
                set: { model.updateSettings($0) }
            ))
        }
    }

    private var connectionStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Monitor")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack {
                Image(systemName: connectionIcon)
                    .foregroundStyle(isConnected && !model.isHeartRateMissing ? .green : .orange)
                Text(connectionStatus)
                    .font(.subheadline)
                Spacer()
                Button(action: { showingDevices = true }) {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            if model.isHeartRateMissing {
                Label("No heart rate received. Check your monitor and Bluetooth connection.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(8)
                    .accessibilityIdentifier("heartRateLossWarning")
            }
        }
    }

    private var sessionPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.currentSession.name)
                        .font(.body.weight(.medium))
                    Text("Warmup: \(model.currentSession.warmupMinutes) min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(model.currentSession.blocks) { block in
                        Text("\(block.repetitions) iterations · \(block.lowerTargetPercent)–\(block.upperTargetPercent)% of max")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button(action: { showingSessions = true }) {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }

    private var heartRateDisplaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Heart rate")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 0) {
                Group {
                    if model.latestSample != nil && !model.isHeartRateMissing {
                        HeartBeatView(trigger: model.heartBeatTrigger)
                    } else {
                        Image(systemName: "heart.slash")
                            .font(.system(size: 40))
                            .foregroundStyle(.orange)
                    }
                }
                    .frame(width: 50, height: 50)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        model.announceHeartRateOnly()
                    }
                
                VStack(spacing: 6) {
                    Text(displayValue)
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(model.isHeartRateMissing ? "No heart rate received" :
                         (model.latestSample == nil ? "Waiting for data" : displayUnit))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .onTapGesture {
                    model.toggleDisplayMode()
                }
                
                Button(action: { showingSettings = true }) {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.blue)
                        .font(.system(size: 24))
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .frame(width: 50, height: 50)
            }
            .frame(height: 100)
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }

    private var startSessionButtonSection: some View {
        Button(action: {
            if model.isRunning {
                model.stopSession()
            } else {
                model.startSession()
            }
        }) {
            Text(model.isRunning ? "Stop Session" : "Start Session")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    model.isRunning ? Color.red :
                    (model.latestSample == nil || !isConnected ? Color.gray : Color.blue)
                )
                .cornerRadius(8)
        }
        .disabled(!model.isRunning && (model.latestSample == nil || !isConnected || model.isHeartRateMissing))
    }

    private var cueMessageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last cue")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(model.lastMessage.isEmpty ? "—" : model.lastMessage)
                .font(.body)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }

    private var isConnected: Bool {
        if case .connected = model.connectionState { return true }
        return false
    }

    private var connectionStatus: String {
        switch model.connectionState {
        case .disconnected: return "No monitor connected"
        case .scanning: return "Searching..."
        case .connecting: return "Connecting..."
        case .connected(let device): return "Connected to \(device.name)"
        }
    }

    private var connectionIcon: String {
        if model.isHeartRateMissing { return "exclamationmark.triangle.fill" }
        return isConnected ? "checkmark.circle.fill" : "xmark.circle"
    }

    private var displayValue: String {
        guard let sample = model.latestSample else { return "--" }
        return model.settings.displayMode == .bpm ? "\(sample.bpm)" : "\(sample.percent)"
    }

    private var displayUnit: String {
        model.settings.displayMode == .bpm ? "BPM" : "% of max"
    }
}

private struct SessionPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    let environment: AppEnvironment
    let model: RunnerViewModel
    @State private var sessions: [SessionTemplate] = []
    @ObservedObject var purchaseManager: PurchaseManager

    init(environment: AppEnvironment, model: RunnerViewModel) {
        self.environment = environment
        self.model = model
        self._purchaseManager = ObservedObject(wrappedValue: environment.purchaseManager)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(sessions) { session in
                    NavigationLink {
                        SessionDetailView(session: session, purchaseManager: purchaseManager) { editedSession in
                            model.selectSession(editedSession)
                            dismiss()
                        }
                        .environmentObject(environment)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(session.name)
                                    .font(.headline)
                                if session.isPremium && !purchaseManager.isPremium {
                                    Image(systemName: "lock.fill")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if !session.notes.isEmpty {
                                Text(session.notes)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("Warmup: \(session.warmupMinutes) min")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ForEach(session.blocks) { block in
                                Text("\(block.repetitions) iterations · \(block.lowerTargetPercent)–\(block.upperTargetPercent)% of max")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(session.isPremium && !purchaseManager.isPremium)
                    .foregroundStyle(.primary)
                }
            }
            .navigationTitle("Select Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            sessions = (try? await environment.sessionStore.loadSessions()) ?? []
        }
    }
}
