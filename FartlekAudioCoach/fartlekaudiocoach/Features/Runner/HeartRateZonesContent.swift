import SwiftUI
import UIKit

extension HeartRateZone {
    var tintColor: UIColor {
        switch self {
        case .moderate: return .systemGray
        case .weightControl: return .systemBlue
        case .aerobic: return .systemGreen
        case .anaerobic: return .systemOrange
        case .vo2Max: return .systemRed
        }
    }
}

struct HeartRateZonesContent: View {
    let maxHeartRate: Int
    let currentBPM: Int?
    @State private var selectedZone: HeartRateZone?

    private var currentZone: HeartRateZone? {
        guard maxHeartRate > 0, let currentBPM, currentBPM > 0 else { return nil }
        return .zone(forPercent: HeartRateConverter.percent(from: currentBPM, maxHeartRate: maxHeartRate))
    }

    var body: some View {
        Section {
            LabeledContent("Maximum heart rate", value: "\(maxHeartRate) BPM")
            if let currentBPM, let currentZone {
                LabeledContent("Current heart rate", value: "\(currentBPM) BPM")
                Label(currentZone.title, systemImage: "heart.fill")
                    .foregroundStyle(Color(currentZone.tintColor))
            }
        } footer: {
            Text("Zones are percentages of your maximum heart rate, not heart-rate reserve. Change your maximum in Settings.")
        }
        Section {
            ForEach(Array(HeartRateZone.allCases.reversed())) { zone in
                Button {
                    selectedZone = zone
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(Color(zone.tintColor))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(zone.title).font(.headline)
                            Text(zone.percentSummary)
                                .font(.subheadline)
                            Text(zone.bpmSummary(maxHeartRate: maxHeartRate))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if currentZone == zone {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color(zone.tintColor))
                                .accessibilityLabel("Current zone")
                        }
                    }
                    .foregroundStyle(.primary)
                    .padding(.vertical, 4)
                }
                .accessibilityIdentifier("heartRateZone-\(zone.rawValue)")
                .listRowBackground(Color(zone.tintColor).opacity(0.12))
            }
        } header: {
            Text("Heart Rate Zones")
        } footer: {
            Text("Tap a zone to learn more. These are general training estimates; use an effort appropriate for your health and fitness.")
        }
        .alert(item: $selectedZone) { zone in
            Alert(title: Text(zone.title), message: Text(zone.explanation), dismissButton: .default(Text("OK")))
        }
    }
}
