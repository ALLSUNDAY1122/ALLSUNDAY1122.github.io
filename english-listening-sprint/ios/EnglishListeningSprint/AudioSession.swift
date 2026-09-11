import AVFoundation

enum AudioSession {
    static func configure() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.allowAirPlay, .allowBluetooth])
            try session.setActive(true)
        } catch {
            assertionFailure("Audio session configuration failed: \(error.localizedDescription)")
        }
    }
}
