import SwiftUI

struct SplatVideoOptionsView: View {
    @Binding var configuration: SplatVideoConfiguration
    let onExport: (SplatVideoConfiguration) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("画面比率") {
                    Picker("画面比率", selection: $configuration.aspectRatio) {
                        ForEach(SplatVideoConfiguration.AspectRatio.allCases) { ratio in
                            Text(ratio.displayName).tag(ratio)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("カメラの動き") {
                    Picker("カメラの動き", selection: $configuration.cameraMotion) {
                        ForEach(SplatVideoConfiguration.CameraMotion.allCases) { motion in
                            Text(motion.displayName).tag(motion)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("速度") {
                    Picker("速度", selection: $configuration.speed) {
                        ForEach(SplatVideoConfiguration.Speed.allCases) { speed in
                            Text(speed.displayName).tag(speed)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text("長さ: \(Int(configuration.duration))秒 / 30fps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("この設定で動画を作る") {
                        let selected = configuration
                        dismiss()
                        onExport(selected)
                    }
                    .frame(maxWidth: .infinity)
                } footer: {
                    Text("動画はGaussian Splatを端末内で再描画してMP4へ保存します。外部送信は行いません。")
                }
            }
            .navigationTitle("動画を書き出す")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}
