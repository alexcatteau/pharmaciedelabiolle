import AVFoundation

/// La session audio est partagée entre l'écoute (micro) et la synthèse (voix de
/// l'interlocuteur). Les faire cohabiter sans se couper mutuellement est la
/// principale source de bugs d'une app de conversation — d'où ce point unique.
enum AudioSessionManager {
    /// Mode conversation : on enregistre et on joue en même temps, haut-parleur
    /// par défaut (personne ne colle son téléphone à l'oreille pour s'entraîner),
    /// et on baisse la musique de l'utilisateur au lieu de la couper.
    static func activateConversationMode() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .spokenAudio,
            options: [.defaultToSpeaker, .allowBluetooth, .duckOthers]
        )
        try session.setActive(true, options: [])
    }

    static func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}
