import SwiftUI

struct TVApp: Identifiable, Codable, Hashable {
    /// Android package name, e.g. `com.netflix.ninja`.
    let id: String
    let name: String
    let color: UInt32
    let symbol: String
    /// Deep link that opens the app. Launching by package (`market://launch?id=`) is unreliable
    /// since a Google Play Store change, so it is only the fallback.
    var link: String? = nil

    var tint: Color {
        Color(red: Double((color >> 16) & 0xff) / 255, green: Double((color >> 8) & 0xff) / 255, blue: Double(color & 0xff) / 255)
    }
}

enum AppCatalog {
    static let builtIn: [TVApp] = [
        TVApp(id: "com.netflix.ninja", name: "Netflix", color: 0xE50914, symbol: "play.rectangle.fill", link: "netflix://"),
        TVApp(id: "com.google.android.youtube.tv", name: "YouTube", color: 0xFF0033, symbol: "play.rectangle.fill", link: "https://www.youtube.com"),
        TVApp(id: "com.amazon.amazonvideo.livingroom", name: "Prime Video", color: 0x1A98FF, symbol: "play.tv.fill", link: "https://app.primevideo.com"),
        TVApp(id: "com.disney.disneyplus", name: "Disney+", color: 0x1F3B9C, symbol: "sparkles.tv.fill", link: "https://www.disneyplus.com"),
        TVApp(id: "com.wbd.stream", name: "HBO Max", color: 0x5822B4, symbol: "film.fill", link: "https://play.hbomax.com"),
        TVApp(id: "com.globo.globotv", name: "Globoplay", color: 0xFF4F2E, symbol: "globe.americas.fill"),
        TVApp(id: "com.apple.atve.androidtv.appletv", name: "Apple TV", color: 0x8E8E93, symbol: "appletv.fill", link: "https://tv.apple.com"),
        TVApp(id: "com.spotify.tv.android", name: "Spotify", color: 0x1ED760, symbol: "music.note", link: "spotify://"),
        TVApp(id: "com.google.android.youtube.tvmusic", name: "YouTube Music", color: 0xFF0033, symbol: "music.note.tv.fill", link: "https://music.youtube.com"),
        TVApp(id: "com.google.android.youtube.tvkids", name: "YouTube Kids", color: 0xFF3D2E, symbol: "figure.and.child.holdinghands"),
        TVApp(id: "com.cbs.ott", name: "Paramount+", color: 0x0064FF, symbol: "mountain.2.fill", link: "https://www.paramountplus.com"),
        TVApp(id: "com.crunchyroll.crunchyroid", name: "Crunchyroll", color: 0xF47521, symbol: "play.circle.fill"),
        TVApp(id: "tv.pluto.android", name: "Pluto TV", color: 0xFFF200, symbol: "tv.fill"),
        TVApp(id: "tv.twitch.android.app", name: "Twitch", color: 0x9146FF, symbol: "bubble.left.and.bubble.right.fill", link: "twitch://home"),
        TVApp(id: "com.plexapp.android", name: "Plex", color: 0xE5A00D, symbol: "server.rack", link: "plex://"),
        TVApp(id: "com.android.vending", name: "Play Store", color: 0x01875F, symbol: "bag.fill")
    ]

    static let defaultFavorites = [
        "com.netflix.ninja", "com.google.android.youtube.tv", "com.amazon.amazonvideo.livingroom", "com.disney.disneyplus",
        "com.wbd.stream", "com.globo.globotv", "com.apple.atve.androidtv.appletv", "com.spotify.tv.android"
    ]

    /// System packages the TV may report as the foreground app.
    private static let systemNames: [String: String] = [
        "com.google.android.tvlauncher": "Tela inicial",
        "com.google.android.apps.tv.launcherx": "Tela inicial",
        "com.google.android.leanbacklauncher": "Tela inicial",
        "com.android.tv.settings": "Configurações",
        "com.google.android.tv.remote.service": "Serviço de controle remoto",
        "com.google.android.katniss": "Google Assistente",
        "com.google.android.apps.mediashell": "Chromecast",
        "com.google.android.tv": "Canais ao vivo",
        "com.mediatek.wwtv.tvcenter": "TV / entrada externa",
        "com.android.tv": "TV / entrada externa",
        "org.droidtv.playtv": "TV / entrada externa",
        "org.droidtv.settings": "Configurações",
        "org.droidtv.nettvlauncher": "Tela inicial"
    ]

    static func displayName(for package: String, custom: [TVApp]) -> String {
        if let app = (builtIn + custom).first(where: { $0.id == package }) { return app.name }
        if let name = systemNames[package] { return name }
        if package.contains("launcher") { return "Tela inicial" }
        return package
    }

    static func isSystemPackage(_ package: String) -> Bool {
        systemNames[package] != nil || package.contains("launcher")
    }
}
