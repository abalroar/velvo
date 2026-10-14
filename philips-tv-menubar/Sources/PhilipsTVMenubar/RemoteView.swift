import SwiftUI

private let accent = Color(red: 0.0, green: 0.55, blue: 0.95)
private let muted = Color.white.opacity(0.5)

private enum Tab: String, CaseIterable, Identifiable {
    case home = "Início", remote = "Controle", apps = "Apps", settings = "Ajustes"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .home: return "tv"
        case .remote: return "dpad"
        case .apps: return "square.grid.2x2"
        case .settings: return "gearshape"
        }
    }
}

private struct Card<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.07)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 0.7))
    }
}

private struct PadButton: ButtonStyle {
    var tint: Color = Color.white.opacity(0.85)
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(tint)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.white.opacity(configuration.isPressed ? 0.16 : 0.07)))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

struct AppTile: View {
    let app: TVApp
    var size: CGFloat = 38
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.26, style: .continuous).fill(app.tint.gradient)
                Image(systemName: app.symbol).font(.system(size: size * 0.42, weight: .semibold)).foregroundStyle(.white)
            }
            .frame(width: size, height: size)
            Text(app.name).font(.system(size: 9.5, weight: .medium)).foregroundStyle(Color.white.opacity(0.75)).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

struct RemoteView: View {
    @ObservedObject var store: RemoteStore
    @State private var tab: Tab = .home
    @State private var text = ""
    @State private var code = ""
    @State private var draftHost = ""
    @State private var draftName = ""
    @State private var draftMAC = ""
    @State private var search = ""
    @State private var newAppName = ""
    @State private var newAppPackage = ""
    @State private var volumeDraft: Double?

    var body: some View {
        VStack(spacing: 0) {
            header.padding(.top, 14).padding(.bottom, 12)
            tabBar.padding(.bottom, 12)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if tab != .settings, !store.isConnected { connectionCard }
                    switch tab {
                    case .home: homeTab
                    case .remote: remoteTab
                    case .apps: appsTab
                    case .settings: settingsTab
                    }
                    feedback
                }
                .padding(.bottom, 14)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 13)
        .frame(width: 360, height: 620)
        .background(LinearGradient(colors: [Color(red: 0.06, green: 0.07, blue: 0.09), Color(white: 0.04)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .foregroundStyle(Color.white.opacity(0.88))
        .font(.system(size: 12))
        .tint(accent)
        .preferredColorScheme(.dark)
        .onAppear {
            draftHost = store.host
            draftName = store.name
            draftMAC = store.mac
            if store.phase == .notConfigured || store.phase == .needsPairing { tab = .settings }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(accent.opacity(0.18))
                Image(systemName: store.isConnected ? "tv.fill" : "tv").font(.system(size: 15)).foregroundStyle(accent)
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.displayName).font(.system(size: 16, weight: .semibold))
                HStack(spacing: 5) {
                    Circle().fill(statusColor).frame(width: 6, height: 6)
                    Text(statusText).font(.system(size: 10, weight: .medium)).foregroundStyle(muted)
                }
            }
            Spacer()
            Menu {
                Button(store.isConnected ? "Desconectar" : "Conectar") { store.isConnected ? store.disconnect() : store.connect() }
                Divider()
                Button("Sair do PhilipsTV Menubar") { NSApplication.shared.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis").frame(width: 24, height: 30).foregroundStyle(muted)
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            Button { store.powerButton() } label: {
                Image(systemName: "power").font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(store.isConnected ? (store.isOn == false ? muted : Color.red.opacity(0.9)) : muted)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.white.opacity(0.07)))
            }
            .buttonStyle(.plain)
            .help(store.isConnected ? "Ligar/desligar a TV" : (store.mac.isEmpty ? "Conectar" : "Ligar a TV pela rede (Wake-on-LAN)"))
        }
    }

    private var statusColor: Color {
        switch store.phase {
        case .connected: return store.isOn == false ? .orange : .green
        case .connecting: return .yellow
        case .needsPairing: return .orange
        default: return muted
        }
    }

    private var statusText: String {
        switch store.phase {
        case .connected: return store.isOn == false ? "Conectada · em espera" : "Conectada"
        case .connecting: return "Conectando…"
        case .needsPairing: return "Precisa parear"
        case .disconnected: return "Desconectada"
        case .notConfigured: return "Não configurada"
        }
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases) { item in
                Button { tab = item } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.symbol).font(.system(size: 14, weight: .medium))
                        Text(item.rawValue).font(.system(size: 9, weight: .medium))
                    }
                    .foregroundStyle(tab == item ? accent : muted)
                    .frame(maxWidth: .infinity).frame(height: 40)
                    .background(RoundedRectangle(cornerRadius: 9).fill(tab == item ? accent.opacity(0.18) : .clear))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
    }

    @ViewBuilder private var connectionCard: some View {
        Card {
            HStack(spacing: 10) {
                if store.phase == .connecting { ProgressView().controlSize(.small) }
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.phase == .needsPairing ? "Pareamento necessário" : store.phase == .notConfigured ? "Configure sua TV" : "TV desconectada")
                        .font(.system(size: 12, weight: .semibold))
                    Text(store.phase == .needsPairing || store.phase == .notConfigured ? "Vá em Ajustes para encontrar e parear a TV." : "Ligue a TV ou tente conectar de novo.")
                        .font(.system(size: 10.5)).foregroundStyle(muted)
                }
                Spacer()
                if store.phase == .disconnected { Button("Conectar") { store.connect() } }
                else if store.phase != .connecting { Button("Ajustes") { tab = .settings } }
            }
        }
    }

    @ViewBuilder private var feedback: some View {
        if let error = store.error {
            Card {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text(error).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button { store.error = nil } label: { Image(systemName: "xmark").font(.system(size: 10)) }.buttonStyle(.plain)
                }
            }
        } else if let notice = store.notice {
            Text(notice).font(.system(size: 11)).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Home

    private var homeTab: some View {
        VStack(spacing: 12) {
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Text("NA TELA AGORA").font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(muted)
                    HStack {
                        if let app = store.allApps.first(where: { $0.id == store.foregroundPackage }) {
                            AppTile(app: app, size: 30).frame(width: 34)
                        }
                        Text(store.isConnected ? store.foregroundName : "—").font(.system(size: 17, weight: .semibold)).lineLimit(1)
                        Spacer()
                        if store.foregroundIsUnknownApp {
                            Button("Salvar app") { store.saveForegroundApp() }
                                .controlSize(.small)
                                .help("Adiciona \(store.foregroundPackage) aos favoritos")
                        }
                    }
                }
            }
            volumeCard
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Favoritos", systemImage: "star.fill").font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Button { tab = .apps } label: { Text("Todos os apps").font(.system(size: 10)).foregroundStyle(muted) }.buttonStyle(.plain)
                    }
                    if store.favoriteApps.isEmpty {
                        Text("Nenhum favorito. Marque apps na aba Apps.").font(.system(size: 11)).foregroundStyle(muted)
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 12) {
                        ForEach(store.favoriteApps) { app in
                            Button { store.launch(app) } label: { AppTile(app: app) }.buttonStyle(.plain).help("Abrir \(app.name) na TV")
                        }
                    }
                    .disabled(!store.isConnected)
                }
            }
            inputsCard
        }
    }

    private var volumeCard: some View {
        Card {
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: store.volume?.muted == true ? "speaker.slash.fill" : "speaker.wave.2.fill").foregroundStyle(muted)
                    Text("Volume").fontWeight(.semibold)
                    Spacer()
                    Text(store.volume.map { "\(volumeDraft.map { Int($0) } ?? $0.level)" } ?? "—")
                        .font(.system(size: 20, weight: .semibold, design: .rounded)).monospacedDigit()
                }
                if let volume = store.volume {
                    Slider(
                        value: Binding(get: { volumeDraft ?? Double(volume.level) }, set: { volumeDraft = $0 }),
                        in: 0...Double(volume.max),
                        onEditingChanged: { editing in
                            if !editing, let target = volumeDraft {
                                store.setVolume(Int(target.rounded()))
                                volumeDraft = nil
                            }
                        }
                    )
                }
                HStack(spacing: 8) {
                    Button { store.send(.mute) } label: { Label(store.volume?.muted == true ? "Ativar som" : "Mudo", systemImage: "speaker.slash").frame(maxWidth: .infinity).frame(height: 26) }.buttonStyle(PadButton())
                    Button { store.send(.volumeDown) } label: { Image(systemName: "minus").frame(width: 44, height: 26) }.buttonStyle(PadButton())
                    Button { store.send(.volumeUp) } label: { Image(systemName: "plus").frame(width: 44, height: 26) }.buttonStyle(PadButton())
                }
            }
            .disabled(!store.isConnected)
        }
    }

    private var inputsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Label("Entradas", systemImage: "cable.connector.horizontal").font(.system(size: 12, weight: .semibold))
                HStack(spacing: 6) {
                    ForEach(Array([KeyCode.hdmi1, .hdmi2, .hdmi3, .hdmi4].enumerated()), id: \.offset) { index, key in
                        Button { store.send(key) } label: { Text("HDMI \(index + 1)").font(.system(size: 11, weight: .medium)).frame(maxWidth: .infinity).frame(height: 28) }
                            .buttonStyle(PadButton())
                    }
                }
                Button { store.send(.input) } label: {
                    Label("Lista de fontes da TV", systemImage: "list.bullet").frame(maxWidth: .infinity).frame(height: 28)
                }
                .buttonStyle(PadButton())
            }
            .disabled(!store.isConnected)
        }
    }

    // MARK: Remote

    private var remoteTab: some View {
        VStack(spacing: 12) {
            Card {
                VStack(spacing: 14) {
                    HStack(spacing: 14) {
                        VStack(spacing: 12) {
                            padIcon("house.fill", "Início", .home)
                            padIcon("arrow.uturn.backward", "Voltar", .back)
                        }
                        dpad
                        VStack(spacing: 12) {
                            padIcon("gearshape.fill", "Configurações da TV", .settings)
                            padIcon("line.3.horizontal", "Menu / opções", .menu)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    HStack(spacing: 6) {
                        padIcon("backward.fill", "Retroceder", .rewind, wide: true)
                        padIcon("backward.end.fill", "Anterior", .previous, wide: true)
                        padIcon("playpause.fill", "Play/pausa", .playPause, wide: true)
                        padIcon("forward.end.fill", "Próximo", .next, wide: true)
                        padIcon("forward.fill", "Avançar", .fastForward, wide: true)
                    }
                    HStack(spacing: 6) {
                        padIcon("mic.fill", "Google Assistente (abre na TV)", .assist, wide: true)
                        padIcon("info.circle", "Informações", .info, wide: true)
                        padIcon("captions.bubble", "Legendas", .captions, wide: true)
                        padIcon("chevron.up.square", "Canal +", .channelUp, wide: true)
                        padIcon("chevron.down.square", "Canal −", .channelDown, wide: true)
                    }
                }
                .disabled(!store.isConnected)
            }
            volumeCard
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Digitar na TV", systemImage: "keyboard").font(.system(size: 12, weight: .semibold))
                    HStack {
                        TextField("Texto para o campo de busca da TV", text: $text)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { store.sendText(text) }
                        Button("Enviar") { store.sendText(text) }.disabled(text.isEmpty)
                    }
                    Text(store.textFieldFocused ? "Campo de texto ativo na TV." : "Abra um campo de busca na TV antes de enviar. O texto substitui o conteúdo do campo.")
                        .font(.system(size: 10)).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true)
                }
                .disabled(!store.isConnected)
            }
            Text("Atalhos com o painel aberto: setas, ↩ OK, ⌫ voltar, espaço play/pausa, H início, M mudo, + / − volume.")
                .font(.system(size: 10)).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var dpad: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.06)).overlay(Circle().strokeBorder(Color.white.opacity(0.08)))
            VStack { arrow("chevron.up", .dpadUp); Spacer(); arrow("chevron.down", .dpadDown) }.padding(6)
            HStack { arrow("chevron.left", .dpadLeft); Spacer(); arrow("chevron.right", .dpadRight) }.padding(6)
            Button { store.send(.dpadCenter) } label: {
                Text("OK").font(.system(size: 13, weight: .semibold))
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(accent.opacity(0.22)))
                    .foregroundStyle(accent)
            }
            .buttonStyle(.plain)
        }
        .frame(width: 146, height: 146)
    }

    private func arrow(_ symbol: String, _ key: KeyCode) -> some View {
        Button { store.send(key) } label: {
            Image(systemName: symbol).font(.system(size: 15, weight: .semibold)).frame(width: 40, height: 40).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func padIcon(_ symbol: String, _ help: String, _ key: KeyCode, wide: Bool = false) -> some View {
        Button { store.send(key) } label: {
            Image(systemName: symbol).font(.system(size: 13, weight: .medium))
                .frame(width: wide ? nil : 44, height: wide ? 30 : 44)
                .frame(maxWidth: wide ? .infinity : nil)
        }
        .buttonStyle(PadButton())
        .help(help)
    }

    // MARK: Apps

    private var appsTab: some View {
        VStack(spacing: 12) {
            TextField("Buscar app", text: $search).textFieldStyle(.roundedBorder)
            Card {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 14) {
                    ForEach(filteredApps) { app in
                        Button { store.launch(app) } label: {
                            AppTile(app: app).overlay(alignment: .topTrailing) {
                                if store.favorites.contains(app.id) {
                                    Image(systemName: "star.fill").font(.system(size: 8)).foregroundStyle(.yellow).offset(x: -6)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(!store.isConnected)
                        .contextMenu {
                            Button(store.favorites.contains(app.id) ? "Remover dos favoritos" : "Adicionar aos favoritos") { store.toggleFavorite(app) }
                            if store.customApps.contains(app) { Button("Excluir app", role: .destructive) { store.removeCustomApp(app) } }
                        }
                        .help("Clique para abrir. Clique com o botão direito para favoritar.")
                    }
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Adicionar outro app", systemImage: "plus.app").font(.system(size: 12, weight: .semibold))
                    TextField("Nome (ex.: Deezer)", text: $newAppName).textFieldStyle(.roundedBorder)
                    TextField("Pacote Android (ex.: deezer.android.tv)", text: $newAppPackage).textFieldStyle(.roundedBorder)
                    HStack {
                        Text("Dica: abra o app na TV e use “Salvar app” na aba Início para capturar o pacote.")
                            .font(.system(size: 10)).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Button("Adicionar") {
                            store.addCustomApp(name: newAppName, package: newAppPackage)
                            newAppName = ""
                            newAppPackage = ""
                        }
                        .disabled(newAppPackage.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }

    private var filteredApps: [TVApp] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return store.allApps }
        return store.allApps.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.id.localizedCaseInsensitiveContains(query) }
    }

    // MARK: Settings

    private var settingsTab: some View {
        VStack(spacing: 12) {
            Card {
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Label("Encontrar TV na rede", systemImage: "wifi").font(.system(size: 12, weight: .semibold))
                        Spacer()
                        if store.discovering { ProgressView().controlSize(.small) }
                        Button("Procurar") { store.discover() }.disabled(store.discovering)
                    }
                    ForEach(store.discovered) { tv in
                        Button {
                            draftHost = tv.host
                            if draftName.isEmpty { draftName = tv.name }
                        } label: {
                            HStack {
                                Image(systemName: "tv")
                                VStack(alignment: .leading) {
                                    Text(tv.name).fontWeight(.medium)
                                    Text(tv.host).font(.system(size: 10)).foregroundStyle(muted)
                                }
                                Spacer()
                                if draftHost == tv.host { Image(systemName: "checkmark").foregroundStyle(accent) }
                            }
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    if !store.discovering, store.discovered.isEmpty {
                        Text("A TV precisa estar ligada. Se não aparecer, digite o IP abaixo (TV: Configurações › Rede › Status da rede).")
                            .font(.system(size: 10)).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Label("TV", systemImage: "tv").font(.system(size: 12, weight: .semibold))
                    field("IP", "192.168.0.50", $draftHost)
                    field("Nome", "Philips TV da sala", $draftName)
                    field("MAC", "Opcional, para ligar pela rede", $draftMAC)
                    HStack {
                        Spacer()
                        Button("Salvar") { store.saveSettings(host: draftHost, name: draftName, mac: draftMAC) }
                            .disabled(draftHost.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            pairingCard
            if let device = store.device {
                Card {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Sobre a TV", systemImage: "info.circle").font(.system(size: 12, weight: .semibold))
                        Text("\(device.vendor) \(device.model)").font(.system(size: 11))
                        Text("Serviço de controle remoto \(device.version)").font(.system(size: 10)).foregroundStyle(muted)
                    }
                }
            }
        }
    }

    private var pairingCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 9) {
                Label("Pareamento", systemImage: "lock.shield").font(.system(size: 12, weight: .semibold))
                switch store.pairing {
                case .idle:
                    Text(store.isPaired ? "Este Mac já está pareado com a TV." : "Com a TV ligada, toque em Parear. Um código de 6 caracteres aparecerá na tela da TV.")
                        .font(.system(size: 11)).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true)
                    HStack {
                        if store.isPaired {
                            Button("Esquecer pareamento", role: .destructive) { store.forgetPairing() }
                        }
                        Spacer()
                        Button(store.isPaired ? "Parear de novo" : "Parear") {
                            store.saveSettings(host: draftHost, name: draftName, mac: draftMAC)
                            code = ""
                            store.startPairing()
                        }
                        .disabled(draftHost.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                case .starting:
                    HStack { ProgressView().controlSize(.small); Text("Pedindo código à TV…") }
                case .awaitingCode, .verifying:
                    HStack {
                        TextField("Código da TV", text: $code)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .onSubmit { store.submitPairingCode(code) }
                        Button("Confirmar") { store.submitPairingCode(code) }
                            .disabled(code.count != 6 || store.pairing == .verifying)
                        Button("Cancelar") { store.cancelPairing() }
                    }
                    if store.pairing == .verifying { HStack { ProgressView().controlSize(.small); Text("Verificando…") } }
                }
            }
        }
    }

    private func field(_ label: String, _ placeholder: String, _ value: Binding<String>) -> some View {
        HStack {
            Text(label).frame(width: 42, alignment: .leading).foregroundStyle(muted)
            TextField(placeholder, text: value).textFieldStyle(.roundedBorder)
        }
    }
}
