import SwiftUI

struct CommunityHomeView: View {
    @Environment(\.currentUserProfile) private var profile
    @State private var clubService = ClubService()
    @State private var mostrarCrear = false
    @State private var mostrarUnirse = false
    @State private var mostrarExploracion = false
    @State private var clubSeleccionado: Club?
    @State private var codigoIngresado = ""
    @State private var errorCodigo: String?
    @State private var buscandoCodigo = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TrazoSpacing.xl) {
                    encabezado
                    accionesRapidas
                    if clubService.cargando && clubService.misClubs.isEmpty {
                        ProgressView().tint(TrazoColors.routeTeal).frame(maxWidth: .infinity).padding(.top, 40)
                    } else if clubService.misClubs.isEmpty {
                        estadoVacio
                    } else {
                        misClubsSection
                    }
                }
                .padding(.horizontal, TrazoSpacing.lg)
                .padding(.bottom, TrazoSpacing.xxxl)
            }
            .background(TrazoColors.background)
            .navigationBarHidden(true)
            .navigationDestination(item: $clubSeleccionado) { club in
                ClubDetailView(club: club)
            }
        }
        .sheet(isPresented: $mostrarCrear) { crearClubSheet }
        .sheet(isPresented: $mostrarUnirse) { unirseSheet }
        .sheet(isPresented: $mostrarExploracion) { ExplorarClubsSheet(onUnirse: { club in
            mostrarExploracion = false
            if !clubService.misClubs.contains(where: { $0.id == club.id }) {
                clubService.misClubs.append(club)
            }
        }) }
        .task {
            guard let uid = profile?.id else { return }
            await clubService.cargarMisClubs(userId: uid)
        }
    }

    // MARK: - Encabezado

    private var encabezado: some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.xs) {
            Text("Comunidad")
                .font(TrazoTypography.largeTitle())
                .foregroundStyle(TrazoColors.textPrimary)
            Text("Corre con amigos, propón rutas y compite.")
                .font(TrazoTypography.body())
                .foregroundStyle(TrazoColors.textSecondary)
        }
        .padding(.top, TrazoSpacing.md)
    }

    // MARK: - Acciones rápidas

    private var accionesRapidas: some View {
        HStack(spacing: TrazoSpacing.md) {
            accionBtn(icon: "plus.circle.fill", label: "Crear club", color: TrazoColors.routeTeal) {
                mostrarCrear = true
            }
            accionBtn(icon: "key.fill", label: "Unirse con código", color: TrazoColors.accentOrange) {
                mostrarUnirse = true
            }
            accionBtn(icon: "magnifyingglass.circle.fill", label: "Explorar", color: .purple) {
                mostrarExploracion = true
            }
        }
    }

    private func accionBtn(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: TrazoSpacing.sm) {
                Image(systemName: icon).font(.title2).foregroundStyle(color)
                Text(label).font(TrazoTypography.caption()).foregroundStyle(TrazoColors.textPrimary).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, TrazoSpacing.lg)
            .background(TrazoColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Mis clubs

    private var misClubsSection: some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.md) {
            Text("Mis clubs").font(TrazoTypography.headline()).foregroundStyle(TrazoColors.textPrimary)
            ForEach(clubService.misClubs) { club in
                Button { clubSeleccionado = club } label: { clubRow(club) }
                    .buttonStyle(.plain)
            }
        }
    }

    private func clubRow(_ club: Club) -> some View {
        TrazoCard {
            HStack(spacing: TrazoSpacing.md) {
                TrazoAvatar(initials: String(club.nombre.prefix(2)).uppercased(), color: TrazoColors.routeTeal)
                VStack(alignment: .leading, spacing: TrazoSpacing.xs) {
                    Text(club.nombre).font(TrazoTypography.headline()).foregroundStyle(TrazoColors.textPrimary)
                    HStack(spacing: TrazoSpacing.sm) {
                        Label(club.codigo, systemImage: "number")
                            .font(TrazoTypography.caption())
                            .foregroundStyle(TrazoColors.textSecondary)
                        if !club.esPublico {
                            Image(systemName: "lock.fill").font(.caption2).foregroundStyle(TrazoColors.textSecondary)
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(TrazoColors.textSecondary)
            }
        }
    }

    // MARK: - Estado vacío

    private var estadoVacio: some View {
        VStack(spacing: TrazoSpacing.lg) {
            Image(systemName: "person.3.fill").font(.system(size: 44)).foregroundStyle(TrazoColors.textSecondary)
            Text("Aún no perteneces a ningún club").font(TrazoTypography.headline()).foregroundStyle(TrazoColors.textPrimary)
            Text("Crea uno o únete con el código de un amigo.").font(TrazoTypography.body()).foregroundStyle(TrazoColors.textSecondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    // MARK: - Sheet crear club

    private var crearClubSheet: some View {
        CrearClubSheet(onCrear: { club in
            mostrarCrear = false
            clubService.misClubs.append(club)
        })
    }

    // MARK: - Sheet unirse con código

    private var unirseSheet: some View {
        NavigationStack {
            VStack(spacing: TrazoSpacing.xl) {
                Image(systemName: "key.fill").font(.system(size: 56)).foregroundStyle(TrazoColors.accentOrange)
                Text("Ingresa el código del club")
                    .font(TrazoTypography.title()).foregroundStyle(TrazoColors.textPrimary)
                TextField("Ej: ABCD12", text: $codigoIngresado)
                    .textInputAutocapitalization(.characters)
                    .font(TrazoTypography.title())
                    .multilineTextAlignment(.center)
                    .padding(TrazoSpacing.lg)
                    .background(TrazoColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.sm, style: .continuous))
                    .padding(.horizontal, TrazoSpacing.xl)
                if let err = errorCodigo {
                    Text(err).font(TrazoTypography.caption()).foregroundStyle(.red)
                }
                TrazoButton(
                    title: buscandoCodigo ? "Buscando..." : "Unirme",
                    isEnabled: codigoIngresado.count >= 6 && !buscandoCodigo
                ) {
                    Task { await unirseConCodigo() }
                }
                .padding(.horizontal, TrazoSpacing.xl)
            }
            .padding(TrazoSpacing.xl)
            .background(TrazoColors.background)
            .navigationBarHidden(true)
        }
        .presentationDetents([.medium])
        .presentationCornerRadius(TrazoRadius.lg)
    }

    private func unirseConCodigo() async {
        guard let uid = profile?.id else { return }
        buscandoCodigo = true
        errorCodigo = nil
        defer { buscandoCodigo = false }
        do {
            let club = try await clubService.unirseConCodigo(codigo: codigoIngresado, userId: uid)
            mostrarUnirse = false
            codigoIngresado = ""
            clubSeleccionado = club
        } catch {
            errorCodigo = "Código inválido. Verifica e intenta de nuevo."
        }
    }
}

// MARK: - Crear club sheet

struct CrearClubSheet: View {
    @Environment(\.currentUserProfile) private var profile
    @Environment(\.dismiss) private var dismiss
    @State private var nombre = ""
    @State private var descripcion = ""
    @State private var esPublico = true
    @State private var guardando = false
    @State private var clubService = ClubService()

    let onCrear: (Club) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: TrazoSpacing.xl) {
                encabezado
                Divider().opacity(0.15)
                ScrollView {
                    VStack(spacing: TrazoSpacing.lg) {
                        campo(label: "Nombre del club", placeholder: "Ej: Corredores del Tec", texto: $nombre)
                        campo(label: "Descripción (opcional)", placeholder: "¿De qué trata tu club?", texto: $descripcion)
                        Toggle(isOn: $esPublico) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Club público").font(TrazoTypography.body()).foregroundStyle(TrazoColors.textPrimary)
                                Text("Cualquiera puede encontrarlo y unirse").font(TrazoTypography.caption()).foregroundStyle(TrazoColors.textSecondary)
                            }
                        }
                        .tint(TrazoColors.routeTeal)
                        .padding(TrazoSpacing.lg)
                        .background(TrazoColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.sm, style: .continuous))
                    }
                    .padding(TrazoSpacing.xl)
                }
                TrazoButton(title: guardando ? "Creando..." : "Crear club", isEnabled: !nombre.isEmpty && !guardando) {
                    Task { await crearClub() }
                }
                .padding(.horizontal, TrazoSpacing.xl)
                .padding(.bottom, TrazoSpacing.xl)
            }
            .background(TrazoColors.background)
            .navigationBarHidden(true)
        }
        .presentationCornerRadius(TrazoRadius.lg)
    }

    private var encabezado: some View {
        HStack {
            Text("Nuevo club").font(TrazoTypography.title()).foregroundStyle(TrazoColors.textPrimary)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(TrazoColors.textSecondary)
            }
        }
        .padding(.horizontal, TrazoSpacing.xl)
        .padding(.top, TrazoSpacing.lg)
    }

    private func campo(label: String, placeholder: String, texto: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.sm) {
            Text(label).font(TrazoTypography.caption()).foregroundStyle(TrazoColors.textSecondary)
            TextField(placeholder, text: texto)
                .font(TrazoTypography.body()).foregroundStyle(TrazoColors.textPrimary)
                .padding(TrazoSpacing.lg)
                .background(TrazoColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.sm, style: .continuous))
        }
    }

    private func crearClub() async {
        guard let uid = profile?.id else { return }
        guardando = true
        defer { guardando = false }
        if let club = try? await clubService.crearClub(nombre: nombre, descripcion: descripcion.isEmpty ? nil : descripcion, esPublico: esPublico, userId: uid) {
            onCrear(club)
        }
    }
}

// MARK: - Explorar clubs sheet

struct ExplorarClubsSheet: View {
    @Environment(\.currentUserProfile) private var profile
    @Environment(\.dismiss) private var dismiss
    @State private var clubs: [Club] = []
    @State private var busqueda = ""
    @State private var cargando = false
    @State private var clubService = ClubService()

    let onUnirse: (Club) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("Explorar clubs").font(TrazoTypography.title()).foregroundStyle(TrazoColors.textPrimary)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(TrazoColors.textSecondary)
                    }
                }
                .padding(.horizontal, TrazoSpacing.xl)
                .padding(.vertical, TrazoSpacing.lg)
                TextField("Buscar clubs...", text: $busqueda)
                    .font(TrazoTypography.body())
                    .padding(TrazoSpacing.md)
                    .background(TrazoColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.sm, style: .continuous))
                    .padding(.horizontal, TrazoSpacing.xl)
                    .onChange(of: busqueda) { _, v in Task { await cargar(v) } }
                ScrollView {
                    LazyVStack(spacing: TrazoSpacing.md) {
                        ForEach(clubs) { club in
                            clubCard(club)
                        }
                    }
                    .padding(TrazoSpacing.xl)
                }
            }
            .background(TrazoColors.background)
            .navigationBarHidden(true)
        }
        .presentationCornerRadius(TrazoRadius.lg)
        .task { await cargar("") }
    }

    private func clubCard(_ club: Club) -> some View {
        TrazoCard {
            HStack(spacing: TrazoSpacing.md) {
                TrazoAvatar(initials: String(club.nombre.prefix(2)).uppercased(), color: .purple)
                VStack(alignment: .leading, spacing: TrazoSpacing.xs) {
                    Text(club.nombre).font(TrazoTypography.headline()).foregroundStyle(TrazoColors.textPrimary)
                    if let desc = club.descripcion, !desc.isEmpty {
                        Text(desc).font(TrazoTypography.caption()).foregroundStyle(TrazoColors.textSecondary).lineLimit(1)
                    }
                }
                Spacer()
                Button("Unirme") {
                    Task { await unirse(club) }
                }
                .font(TrazoTypography.caption())
                .foregroundStyle(.white)
                .padding(.horizontal, TrazoSpacing.md).padding(.vertical, TrazoSpacing.sm)
                .background(TrazoColors.routeTeal)
                .clipShape(Capsule())
            }
        }
    }

    private func cargar(_ texto: String) async {
        clubs = (try? await clubService.clubsPublicos(busqueda: texto)) ?? []
    }

    private func unirse(_ club: Club) async {
        guard let uid = profile?.id else { return }
        if let c = try? await clubService.unirseConCodigo(codigo: club.codigo, userId: uid) {
            onUnirse(c)
        }
    }
}
