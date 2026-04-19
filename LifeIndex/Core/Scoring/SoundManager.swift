import AVFoundation

/// Manages sound playback for the app
class SoundManager {
    static let shared = SoundManager()

    private var audioPlayer: AVAudioPlayer?

    private init() {}

    /// Plays the streak success sound
    func playStreakSuccess() {
        playSound(named: "streak-success-sfx-1", extension: "mp3")
    }

    /// Generic method to play a sound file from the bundle
    func playSound(named name: String, extension ext: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            debugLog("[SoundManager] Sound file not found: \(name).\(ext)")
            return
        }

        do {
            // Configure audio session for playback
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            debugLog("[SoundManager] Error playing sound: \(error.localizedDescription)")
        }
    }
}
