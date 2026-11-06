#if canImport(AVFAudio)
import AVFAudio
import Foundation

@main
struct L3AW29ApplePlaybackCompileSurfaceSelfTest {
    static func main() {
        Lane3ApplePlaybackCompileSurface.requireSelectedSurface()
        _ = Lane3AppleFilePCMChunkSource.self
        _ = Lane3AppleLongTrackEvidenceInputFactory.self
        _ = AppleRampedMultiTrackPlaybackBackend.self
        print("L3-AW29 Apple Playback compile surface PASS")
    }
}
#else
import Foundation

@main
struct L3AW29ApplePlaybackCompileSurfaceSelfTest {
    static func main() {
        print("L3-AW29 Apple Playback compile surface SKIPPED_NO_AVFAUDIO")
    }
}
#endif
