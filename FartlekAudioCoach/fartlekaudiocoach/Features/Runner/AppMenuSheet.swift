import SwiftUI

enum AppMenuSelection: String, CaseIterable, Identifiable {
    case purchase, help, heartRateZones, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .purchase: return "Buy app"
        case .help: return "Help"
        case .heartRateZones: return "Heart Rate Zones"
        case .about: return "About"
        }
    }

    var symbol: String {
        switch self {
        case .purchase: return "cart"
        case .help: return "questionmark.circle"
        case .heartRateZones: return "heart.text.square"
        case .about: return "info.circle"
        }
    }

    var destination: AppMenuDestination {
        switch self {
        case .purchase: return .purchase
        case .help: return .help
        case .heartRateZones: return .heartRateZones
        case .about: return .about
        }
    }
}

struct AppMenuSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (AppMenuSelection) -> Void

    var body: some View {
        NavigationStack {
            List(AppMenuSelection.allCases) { selection in
                Button {
                    onSelect(selection)
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: selection.symbol)
                            .foregroundStyle(.blue)
                            .frame(width: 28)
                        Text(selection.title)
                            .font(.title3)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(selection == .heartRateZones ? "showHeartRateZones" : "menu-\(selection.rawValue)")
            }
            .navigationTitle("Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}
