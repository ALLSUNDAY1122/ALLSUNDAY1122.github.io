import Foundation
import AVFoundation

/// BGMプレイヤー。Resources の bgm.m4a を小さな音量でループ再生する。
/// 音源が無い・読み込めない場合は何もしない（クラッシュさせない）。
/// 有効/無効は UserDefaults の "kanji-bgm-enabled"（未設定なら有効）で永続化する。
@MainActor
final class BGMPlayer: ObservableObject {
    static let shared = BGMPlayer()

    @Published private(set) var enabled: Bool

    private var player: AVAudioPlayer?
    private static let defaultsKey = "kanji-bgm-enabled"

    init() {
        if UserDefaults.standard.object(forKey: Self.defaultsKey) == nil {
            enabled = true
        } else {
            enabled = UserDefaults.standard.bool(forKey: Self.defaultsKey)
        }
    }

    /// 起動時：有効なら再生を始める。
    func startIfEnabled() {
        guard enabled else { return }
        play()
    }

    /// 設定のオン/オフ。保存して、オンなら再生開始、オフなら停止する。
    func setEnabled(_ on: Bool) {
        enabled = on
        UserDefaults.standard.set(on, forKey: Self.defaultsKey)
        if on {
            play()
        } else {
            player?.stop()
            player = nil
        }
    }

    /// バックグラウンドへ移ったときに一時停止する。
    func pause() {
        player?.pause()
    }

    /// フォアグラウンドへ戻ったとき、有効なら再生を再開する。
    func resumeIfEnabled() {
        guard enabled else { return }
        play()
    }

    private func play() {
        if let player {
            if !player.isPlaying {
                player.play()
            }
            return
        }
        guard let url = Bundle.main.url(forResource: "bgm", withExtension: "m4a") else {
            return
        }
        do {
            // .ambient：消音スイッチに従い、他の音声を邪魔しない。
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.numberOfLoops = -1
            newPlayer.volume = 0.12
            newPlayer.prepareToPlay()
            newPlayer.play()
            player = newPlayer
        } catch {
            player = nil
        }
    }
}
