import MapKit
import SwiftUI

enum RunningSearchMetrics {
    static let collapsedBarHeight = TrazoBottomChromeMetrics.searchZoneHeight
}

// MARK: - Collapsed bar (fondo gris unificado: search + navbar)

struct RunningCollapsedSearchBar: View {
    let onTap: () -> Void

    var body: some View {
        TrazoBottomSearchButton(placeholder: "Buscar dirección", onTap: onTap)
    }
}

// MARK: - Sheet de búsqueda (expandido, gestos nativos)

struct RunningLocationSearchSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var searchService: AddressSearchService
    @Bindable var searchHistory: SearchHistoryStore
    let popularLocations: [PopularLocation]
    let onSelect: (MapDestination) -> Void

    @State private var isResolving = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                    .padding(.horizontal, TrazoSpacing.lg)
                    .padding(.vertical, TrazoSpacing.md)

                Divider()
                    .overlay(TrazoColors.elevated.opacity(0.4))

                searchResultsList
            }
            .background(TrazoColors.surface)
            .navigationTitle("Buscar dirección")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(TrazoColors.surface, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .overlay {
                if isResolving {
                    ProgressView()
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))
                }
            }
        }
        .onAppear {
            isSearchFocused = true
        }
    }

    private var searchField: some View {
        HStack(spacing: TrazoSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(TrazoColors.textSecondary)

            TextField("Buscar dirección", text: $searchService.query)
                .font(TrazoTypography.body())
                .foregroundStyle(TrazoColors.textPrimary)
                .focused($isSearchFocused)
                .submitLabel(.search)

            if !searchService.query.isEmpty {
                Button {
                    searchService.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(TrazoColors.textSecondary)
                }
            }
        }
        .padding(.horizontal, TrazoSpacing.lg)
        .padding(.vertical, TrazoSpacing.md)
        .background(TrazoColors.elevated.opacity(0.5))
        .clipShape(Capsule())
    }

    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if searchService.query.isEmpty {
                    if !searchHistory.items.isEmpty {
                        sectionHeader("Recientes")
                        ForEach(searchHistory.items) { item in
                            locationRow(title: item.title, subtitle: item.subtitle) {
                                selectRecent(item)
                            }
                        }
                    }

                    sectionHeader("Populares")
                    ForEach(popularLocations) { location in
                        locationRow(title: location.name, subtitle: location.subtitle) {
                            await selectPopular(location)
                        }
                    }
                } else if searchService.results.isEmpty {
                    Text("Sin resultados")
                        .font(TrazoTypography.body())
                        .foregroundStyle(TrazoColors.textSecondary)
                        .padding(TrazoSpacing.lg)
                } else {
                    sectionHeader("Cercanos")
                    ForEach(Array(searchService.results.enumerated()), id: \.offset) { _, result in
                        locationRow(title: result.title, subtitle: result.subtitle) {
                            await selectCompletion(result)
                        }
                    }
                }
            }
            .padding(.bottom, TrazoSpacing.lg)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(TrazoTypography.caption())
            .foregroundStyle(TrazoColors.textSecondary)
            .padding(.horizontal, TrazoSpacing.lg)
            .padding(.vertical, TrazoSpacing.sm)
    }

    private func locationRow(
        title: String,
        subtitle: String,
        action: @escaping () async -> Void
    ) -> some View {
        Button {
            Task { await action() }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(TrazoTypography.body())
                    .foregroundStyle(TrazoColors.textPrimary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(TrazoTypography.caption())
                        .foregroundStyle(TrazoColors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, TrazoSpacing.lg)
            .padding(.vertical, TrazoSpacing.md)
        }
        .buttonStyle(.plain)
    }

    private func selectRecent(_ item: RecentSearch) {
        let destination = item.asMapDestination()
        finishSelection(destination, title: item.title, subtitle: item.subtitle)
    }

    private func selectPopular(_ location: PopularLocation) async {
        isResolving = true
        defer { isResolving = false }
        do {
            let destination = try await location.asMapDestination()
            finishSelection(destination, title: location.name, subtitle: location.subtitle)
        } catch {}
    }

    private func selectCompletion(_ result: MKLocalSearchCompletion) async {
        isResolving = true
        defer { isResolving = false }
        do {
            let destination = try await searchService.resolve(result)
            finishSelection(destination, title: result.title, subtitle: result.subtitle)
        } catch {}
    }

    private func finishSelection(
        _ destination: MapDestination,
        title: String,
        subtitle: String = ""
    ) {
        searchHistory.add(destination: destination, title: title, subtitle: subtitle)
        searchService.query = ""
        searchService.results = []
        onSelect(destination)
        dismiss()
    }
}
