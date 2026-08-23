import SwiftUI

struct HostStatusView: View {
    let slots: HostModuleSlots
    private let smoke = ApplePlatformSmoke.run()

    var body: some View {
        NavigationStack {
            List {
                Section("Epoch 2 standalone host") {
                    Label("Frozen Shared/App contracts loaded", systemImage: "checkmark.seal")
                    Text("This diagnostic shell does not copy other Lane implementations. HQ injects them during Late Integration.")
                        .font(.footnote)
                }

                Section("Module slots") {
                    if slots.missingLateIntegrationModules.isEmpty {
                        Label("All late-integration modules injected", systemImage: "checkmark.circle")
                    } else {
                        ForEach(slots.missingLateIntegrationModules, id: \.self) { slot in
                            HStack {
                                Text(slot.rawValue)
                                Spacer()
                                Text("pending")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Apple platform smoke") {
                    LabeledContent("AVFoundation", value: smoke.avFoundationAvailable ? "available" : "unavailable")
                    LabeledContent("AVFAudio", value: smoke.avFAudioAvailable ? "available" : "unavailable")
                    if !smoke.linkedTypeNames.isEmpty {
                        Text(smoke.linkedTypeNames.joined(separator: " • "))
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                }

                Section("Evidence boundary") {
                    Text("Compile/link success is not PARITY. Physical-device audio routing, latency, thermal behavior, real-audio quality and cross-Lane compilation remain HQ Late Integration gates.")
                        .font(.footnote)
                }
            }
            .navigationTitle("Lane 4 Host")
        }
    }
}
