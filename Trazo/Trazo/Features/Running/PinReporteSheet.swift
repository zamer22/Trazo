import CoreLocation
import SwiftUI
import UIKit

// MARK: - Camera picker wrapper

private struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let vc = UIImagePickerController()
        vc.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage) -> Void
        init(onImage: @escaping (UIImage) -> Void) { self.onImage = onImage }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                onImage(img)
            }
            picker.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

struct PinReporteSheet: View {
    @Environment(\.currentUserProfile) private var profile
    @Environment(\.dismiss) private var dismiss

    enum ModoPicker: String, CaseIterable {
        case foto    = "📷 Foto + IA"
        case manual  = "✏️ Manual"
    }

    @State private var modo: ModoPicker = .foto
    @State private var clasificador = ClasificadorFotoService()
    @State private var mostrarCamara = false
    @State private var imagenUI: UIImage?
    @State private var tipoManual: String? = nil
    @State private var guardando = false
    @State private var errorMsg: String?

    let userLocation: CLLocationCoordinate2D?
    let userId: UUID?
    let onPinReportado: (String, CLLocationCoordinate2D) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                encabezado
                Divider().opacity(0.15)
                Picker("Modo", selection: $modo) {
                    ForEach(ModoPicker.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, TrazoSpacing.xl)
                .padding(.vertical, TrazoSpacing.md)
                .onChange(of: modo) { _, _ in
                    tipoManual = nil
                    clasificador.reiniciar()
                    imagenUI = nil
                }
                Divider().opacity(0.15)
                ScrollView {
                    VStack(spacing: TrazoSpacing.xl) {
                        if modo == .foto {
                            fotoSection
                            estadoSection
                        } else {
                            modoManualSection
                        }
                    }
                    .padding(TrazoSpacing.xl)
                }
                botonReportar
                    .padding(.horizontal, TrazoSpacing.xl)
                    .padding(.bottom, TrazoSpacing.xl)
            }
            .background(TrazoColors.background)
            .alert("No se pudo reportar", isPresented: .init(
                get: { errorMsg != nil },
                set: { if !$0 { errorMsg = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: { Text(errorMsg ?? "") }
        }
    }

    // MARK: - Encabezado

    private var encabezado: some View {
        HStack {
            HStack(spacing: TrazoSpacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(TrazoColors.accentOrange)
                Text("Reportar problema")
                    .font(TrazoTypography.title())
                    .foregroundStyle(TrazoColors.textPrimary)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(TrazoColors.textSecondary)
            }
        }
        .padding(.horizontal, TrazoSpacing.xl)
        .padding(.vertical, TrazoSpacing.lg)
    }

    // MARK: - Foto

    private var fotoSection: some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.sm) {
            Text("Toma una foto del problema")
                .font(TrazoTypography.caption())
                .foregroundStyle(TrazoColors.textSecondary)

            Button { mostrarCamara = true } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous)
                        .fill(TrazoColors.surface)
                        .frame(height: 180)

                    if let imagen = imagenUI {
                        Image(uiImage: imagen)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))
                    } else {
                        VStack(spacing: TrazoSpacing.sm) {
                            Image(systemName: "camera.fill")
                                .font(.largeTitle)
                                .foregroundStyle(TrazoColors.textSecondary)
                            Text("Tomar foto")
                                .font(TrazoTypography.body())
                                .foregroundStyle(TrazoColors.textSecondary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .fullScreenCover(isPresented: $mostrarCamara) {
                CameraPicker { img in
                    imagenUI = img
                    Task { await clasificador.analizar(img) }
                }
                .ignoresSafeArea()
            }
        }
    }

    // MARK: - Estado clasificador

    @ViewBuilder
    private var estadoSection: some View {
        switch clasificador.estado {
        case .inactivo:
            EmptyView()
        case .analizando:
            HStack(spacing: TrazoSpacing.md) {
                ProgressView().tint(TrazoColors.routeTeal)
                Text("Analizando con IA...")
                    .font(TrazoTypography.body())
                    .foregroundStyle(TrazoColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(TrazoSpacing.xl)
        case .detectado(let tipo):
            resultadoCard(tipo: tipo)
        case .sinProblema:
            noProblemaView
        case .error(let msg):
            Text(msg)
                .font(TrazoTypography.caption())
                .foregroundStyle(.red.opacity(0.8))
        }
    }

    private func resultadoCard(tipo: String) -> some View {
        HStack(spacing: TrazoSpacing.md) {
            Image(systemName: iconoPorTipo(tipo))
                .foregroundStyle(.white)
                .padding(TrazoSpacing.md)
                .background(colorPorTipo(tipo))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("Detectado: \(etiquetaPorTipo(tipo))")
                    .font(TrazoTypography.headline())
                    .foregroundStyle(TrazoColors.textPrimary)
                Text("IA identificó un problema para corredores")
                    .font(TrazoTypography.caption())
                    .foregroundStyle(TrazoColors.textSecondary)
            }
            Spacer()
        }
        .padding(TrazoSpacing.lg)
        .background(TrazoColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))
    }

    private var noProblemaView: some View {
        HStack(spacing: TrazoSpacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title2)
            Text("La IA no detectó un problema real en esta foto.")
                .font(TrazoTypography.body())
                .foregroundStyle(TrazoColors.textSecondary)
        }
        .padding(TrazoSpacing.lg)
        .background(TrazoColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))
    }

    // MARK: - Modo manual

    private let tiposPin = ["bache", "basura", "inundacion", "obra", "obstaculo", "peligro"]

    private var modoManualSection: some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.md) {
            Text("¿Qué encontraste?")
                .font(TrazoTypography.caption())
                .foregroundStyle(TrazoColors.textSecondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: TrazoSpacing.md) {
                ForEach(tiposPin, id: \.self) { tipo in
                    let seleccionado = tipoManual == tipo
                    Button { tipoManual = tipo } label: {
                        VStack(spacing: TrazoSpacing.sm) {
                            Image(systemName: iconoPorTipo(tipo))
                                .font(.title2)
                                .foregroundStyle(seleccionado ? .white : colorPorTipo(tipo))
                            Text(etiquetaPorTipo(tipo))
                                .font(TrazoTypography.caption())
                                .foregroundStyle(seleccionado ? .white : TrazoColors.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, TrazoSpacing.lg)
                        .background(seleccionado ? colorPorTipo(tipo) : TrazoColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.sm, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Botón

    @ViewBuilder
    private var botonReportar: some View {
        if modo == .manual {
            if let tipo = tipoManual {
                TrazoButton(title: guardando ? "Guardando..." : "Reportar \(etiquetaPorTipo(tipo))", isEnabled: !guardando) {
                    Task { await guardarPin(tipo: tipo) }
                }
            }
        } else {
            if case .detectado(let tipo) = clasificador.estado {
                TrazoButton(title: guardando ? "Guardando..." : "Reportar pin", isEnabled: !guardando) {
                    Task { await guardarPin(tipo: tipo) }
                }
            } else if case .sinProblema = clasificador.estado {
                TrazoButton(title: "Cerrar", style: .secondary) { dismiss() }
            }
        }
    }

    // MARK: - Lógica

    private func guardarPin(tipo: String) async {
        guard let loc = userLocation, let uid = userId ?? profile?.id else {
            errorMsg = "No se pudo obtener tu ubicación o usuario."
            return
        }
        guardando = true
        defer { guardando = false }
        do {
            try await PinAdvertenciaService.reportar(tipo: tipo, coordenada: loc, userId: uid)
            onPinReportado(tipo, loc)
            dismiss()
        } catch {
            errorMsg = "No se pudo guardar el reporte. Intenta de nuevo."
        }
    }

    private func iconoPorTipo(_ t: String) -> String {
        switch t {
        case "bache":      return "exclamationmark.triangle.fill"
        case "basura":     return "trash.fill"
        case "inundacion": return "drop.fill"
        case "obra":       return "hammer.fill"
        case "obstaculo":  return "xmark.octagon.fill"
        default:           return "exclamationmark.shield.fill"
        }
    }

    private func colorPorTipo(_ t: String) -> Color {
        switch t {
        case "inundacion": return .blue
        case "obra":       return .orange
        case "basura":     return .gray
        default:           return .red
        }
    }

    private func etiquetaPorTipo(_ t: String) -> String {
        switch t {
        case "bache":      return "Bache"
        case "basura":     return "Basura"
        case "inundacion": return "Inundado"
        case "obra":       return "Obra"
        case "obstaculo":  return "Obstáculo"
        default:           return "Peligro"
        }
    }
}
