import SwiftUI

struct ClubDetailView: View {
    @Environment(\.currentUserProfile) private var profile
    @Environment(\.dismiss) private var dismiss

    let club: Club

    @State private var clubService = ClubService()
    @State private var tab: Tab = .chat
    @State private var mensajeTexto = ""
    @State private var mostrarMarioKart = false
    @State private var enviando = false

    enum Tab { case chat, sesion }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                encabezado
                Divider().opacity(0.15)
                Picker("", selection: $tab) {
                    Text("Chat").tag(Tab.chat)
                    Text("Rally").tag(Tab.sesion)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, TrazoSpacing.xl)
                .padding(.vertical, TrazoSpacing.md)
                .onChange(of: tab) { _, nuevo in
                    clubService.detenerPolling()
                    if let uid = profile?.id {
                        if nuevo == .chat {
                            clubService.iniciarPollingMensajes(clubId: club.id)
                        } else {
                            clubService.iniciarPollingSesion(clubId: club.id)
                        }
                    }
                }
                Divider().opacity(0.15)
                Group {
                    switch tab {
                    case .chat:   chatTab
                    case .sesion: sesionTab
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(TrazoColors.background)
            if tab == .chat { inputBar }
        }
        .navigationBarHidden(true)
        .task {
            await clubService.cargarMensajes(clubId: club.id)
            await clubService.cargarSesionActiva(clubId: club.id)
            clubService.iniciarPollingMensajes(clubId: club.id)
        }
        .onDisappear { clubService.detenerPolling() }
        .fullScreenCover(isPresented: $mostrarMarioKart) {
            if let sesion = clubService.sesionActiva {
                MarioKartSessionView(club: club, sesion: sesion, clubService: clubService)
            }
        }
    }

    // MARK: - Encabezado

    private var encabezado: some View {
        HStack(spacing: TrazoSpacing.md) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.title3.weight(.semibold)).foregroundStyle(TrazoColors.textPrimary)
            }
            TrazoAvatar(initials: String(club.nombre.prefix(2)).uppercased(), color: TrazoColors.routeTeal)
            VStack(alignment: .leading, spacing: 2) {
                Text(club.nombre).font(TrazoTypography.headline()).foregroundStyle(TrazoColors.textPrimary)
                Text("Código: \(club.codigo)").font(TrazoTypography.caption()).foregroundStyle(TrazoColors.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, TrazoSpacing.lg)
        .padding(.vertical, TrazoSpacing.md)
    }

    // MARK: - Chat

    private var chatTab: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: TrazoSpacing.sm) {
                    ForEach(clubService.mensajes) { msg in
                        burbuja(msg)
                            .id(msg.id)
                    }
                }
                .padding(.horizontal, TrazoSpacing.lg)
                .padding(.top, TrazoSpacing.md)
                .padding(.bottom, 90)
            }
            .onChange(of: clubService.mensajes.count) { _, _ in
                if let last = clubService.mensajes.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private func burbuja(_ msg: ClubMensaje) -> some View {
        let esMio = msg.userId == profile?.id
        return HStack(alignment: .bottom, spacing: TrazoSpacing.sm) {
            if esMio { Spacer() }
            VStack(alignment: esMio ? .trailing : .leading, spacing: 3) {
                if !esMio {
                    Text(msg.nombreUsuario).font(TrazoTypography.caption()).foregroundStyle(TrazoColors.textSecondary)
                }
                Text(msg.contenido)
                    .font(TrazoTypography.body())
                    .foregroundStyle(esMio ? .white : TrazoColors.textPrimary)
                    .padding(.horizontal, TrazoSpacing.md)
                    .padding(.vertical, TrazoSpacing.sm)
                    .background(esMio ? TrazoColors.routeTeal : TrazoColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            if !esMio { Spacer() }
        }
    }

    private var inputBar: some View {
        HStack(spacing: TrazoSpacing.md) {
            TextField("Mensaje...", text: $mensajeTexto)
                .font(TrazoTypography.body()).foregroundStyle(TrazoColors.textPrimary)
                .padding(.horizontal, TrazoSpacing.md).padding(.vertical, TrazoSpacing.sm)
                .background(TrazoColors.surface)
                .clipShape(Capsule())
            Button {
                Task { await enviarMensaje() }
            } label: {
                Image(systemName: "paperplane.fill")
                    .foregroundStyle(.white)
                    .padding(TrazoSpacing.md)
                    .background(mensajeTexto.isEmpty ? Color.gray : TrazoColors.routeTeal)
                    .clipShape(Circle())
            }
            .disabled(mensajeTexto.isEmpty || enviando)
        }
        .padding(.horizontal, TrazoSpacing.lg)
        .padding(.vertical, TrazoSpacing.md)
        .background(.ultraThinMaterial)
    }

    private func enviarMensaje() async {
        guard let uid = profile?.id, !mensajeTexto.isEmpty else { return }
        let texto = mensajeTexto
        mensajeTexto = ""
        enviando = true
        defer { enviando = false }
        try? await clubService.enviarMensaje(
            clubId: club.id, userId: uid,
            nombreUsuario: profile?.displayName ?? "Runner",
            contenido: texto
        )
        await clubService.cargarMensajes(clubId: club.id)
    }

    // MARK: - Sesión tab

    private var sesionTab: some View {
        ScrollView {
            VStack(spacing: TrazoSpacing.xl) {
                if let sesion = clubService.sesionActiva {
                    sesionActivaView(sesion)
                } else {
                    crearSesionView
                }
            }
            .padding(TrazoSpacing.xl)
        }
        .task { await clubService.cargarSesionActiva(clubId: club.id) }
    }

    private var crearSesionView: some View {
        VStack(spacing: TrazoSpacing.xl) {
            Image(systemName: "dice.fill")
                .font(.system(size: 56))
                .foregroundStyle(TrazoColors.accentOrange)
            Text("Rally Mode")
                .font(TrazoTypography.title())
                .foregroundStyle(TrazoColors.textPrimary)
            Text("Propón una ruta, voten en el club o activen la ruleta — ¡y salgan a correr juntos!")
                .font(TrazoTypography.body())
                .foregroundStyle(TrazoColors.textSecondary)
                .multilineTextAlignment(.center)
            VStack(spacing: TrazoSpacing.md) {
                TrazoButton(title: "Modo Ruleta") {
                    Task { await crearSesion(modo: "ruleta") }
                }
                TrazoButton(title: "Modo Votación", style: .secondary) {
                    Task { await crearSesion(modo: "votacion") }
                }
            }
        }
        .padding(.top, 40)
    }

    private func sesionActivaView(_ sesion: SesionClub) -> some View {
        VStack(spacing: TrazoSpacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sesión activa")
                        .font(TrazoTypography.headline()).foregroundStyle(TrazoColors.textPrimary)
                    Text(sesion.modo == "ruleta" ? "Modo Ruleta" : "Modo Votación")
                        .font(TrazoTypography.caption()).foregroundStyle(TrazoColors.textSecondary)
                }
                Spacer()
                estadoBadge(sesion.estado)
            }
            .padding(TrazoSpacing.lg)
            .background(TrazoColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))

            TrazoButton(title: "Ver sesión y proponer ruta") {
                mostrarMarioKart = true
            }
        }
    }

    private func estadoBadge(_ estado: String) -> some View {
        let color: Color = estado == "corriendo" ? .green : TrazoColors.accentOrange
        let label = estado == "corriendo" ? "Corriendo" : "Esperando"
        return Text(label)
            .font(TrazoTypography.caption())
            .foregroundStyle(.white)
            .padding(.horizontal, TrazoSpacing.md).padding(.vertical, 4)
            .background(color)
            .clipShape(Capsule())
    }

    private func crearSesion(modo: String) async {
        guard let uid = profile?.id else { return }
        _ = try? await clubService.crearSesion(clubId: club.id, modo: modo, userId: uid)
        mostrarMarioKart = true
    }
}
