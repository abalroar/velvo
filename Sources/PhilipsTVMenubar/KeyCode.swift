/// Android `KeyEvent` codes accepted by the Android TV Remote Service.
enum KeyCode: Int, CaseIterable {
    case home = 3, back = 4
    case digit0 = 7, digit1, digit2, digit3, digit4, digit5, digit6, digit7, digit8, digit9
    case dpadUp = 19, dpadDown = 20, dpadLeft = 21, dpadRight = 22, dpadCenter = 23
    case volumeUp = 24, volumeDown = 25, power = 26
    case enter = 66, del = 67
    case menu = 82, search = 84
    case playPause = 85, stop = 86, next = 87, previous = 88, rewind = 89, fastForward = 90
    case play = 126, pause = 127
    case mute = 164, info = 165, channelUp = 166, channelDown = 167
    case guide = 172, captions = 175, settings = 176, input = 178
    case red = 183, green = 184, yellow = 185, blue = 186
    case assist = 219, sleep = 223, wakeup = 224
    case hdmi1 = 243, hdmi2 = 244, hdmi3 = 245, hdmi4 = 246
    case allApps = 284

    /// Name used by the command line (`--send-key HOME`), matching Android's `KEYCODE_` suffix.
    var name: String {
        switch self {
        case .home: return "HOME"
        case .back: return "BACK"
        case .dpadUp: return "DPAD_UP"
        case .dpadDown: return "DPAD_DOWN"
        case .dpadLeft: return "DPAD_LEFT"
        case .dpadRight: return "DPAD_RIGHT"
        case .dpadCenter: return "DPAD_CENTER"
        case .volumeUp: return "VOLUME_UP"
        case .volumeDown: return "VOLUME_DOWN"
        case .power: return "POWER"
        case .enter: return "ENTER"
        case .del: return "DEL"
        case .menu: return "MENU"
        case .search: return "SEARCH"
        case .playPause: return "MEDIA_PLAY_PAUSE"
        case .stop: return "MEDIA_STOP"
        case .next: return "MEDIA_NEXT"
        case .previous: return "MEDIA_PREVIOUS"
        case .rewind: return "MEDIA_REWIND"
        case .fastForward: return "MEDIA_FAST_FORWARD"
        case .play: return "MEDIA_PLAY"
        case .pause: return "MEDIA_PAUSE"
        case .mute: return "VOLUME_MUTE"
        case .info: return "INFO"
        case .channelUp: return "CHANNEL_UP"
        case .channelDown: return "CHANNEL_DOWN"
        case .guide: return "GUIDE"
        case .captions: return "CAPTIONS"
        case .settings: return "SETTINGS"
        case .input: return "TV_INPUT"
        case .red: return "PROG_RED"
        case .green: return "PROG_GREEN"
        case .yellow: return "PROG_YELLOW"
        case .blue: return "PROG_BLUE"
        case .assist: return "ASSIST"
        case .sleep: return "SLEEP"
        case .wakeup: return "WAKEUP"
        case .hdmi1: return "TV_INPUT_HDMI_1"
        case .hdmi2: return "TV_INPUT_HDMI_2"
        case .hdmi3: return "TV_INPUT_HDMI_3"
        case .hdmi4: return "TV_INPUT_HDMI_4"
        case .allApps: return "ALL_APPS"
        default: return String(rawValue - KeyCode.digit0.rawValue)
        }
    }

    init?(name: String) {
        let upper = name.uppercased().replacingOccurrences(of: "KEYCODE_", with: "")
        guard let match = KeyCode.allCases.first(where: { $0.name == upper }) else { return nil }
        self = match
    }
}
