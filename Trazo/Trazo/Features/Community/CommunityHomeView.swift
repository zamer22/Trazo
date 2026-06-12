import SwiftData
import SwiftUI

struct CommunityHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appNavigation) private var navigation

    @Query(sort: \RunningClub.lastMessageAt, order: .reverse)
    private var storedClubs: [RunningClub]

    @State private var searchText = ""
    @State private var showsCreateClub = false
    @State private var showsJoinClub = false

    private var clubs: [RunningClub] {
        storedClubs.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
            return lhs.lastMessageAt > rhs.lastMessageAt
        }
    }

    private var filteredClubs: [RunningClub] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return clubs }
        return clubs.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.lastMessage.localizedCaseInsensitiveContains(query)
        }
    }

    private var pinnedClub: RunningClub? {
        filteredClubs.first { $0.isPinned }
    }

    private var otherClubs: [RunningClub] {
        filteredClubs.filter { !$0.isPinned }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    header

                    ScrollView {
                        LazyVStack(spacing: TrazoSpacing.md) {
                            if let pinnedClub {
                                pinnedClubCard(pinnedClub)
                            }

                            if !otherClubs.isEmpty {
                                sectionHeader("Tus clubs")

                                ForEach(otherClubs) { club in
                                    NavigationLink(value: club) {
                                        clubRow(club, isPinned: false)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            if filteredClubs.isEmpty {
                                emptySearchState
                            }
                        }
                        .padding(.horizontal, TrazoSpacing.lg)
                        .padding(.bottom, 100)
                    }
                }

                TrazoBottomSearchBar(text: $searchText, placeholder: "Buscar clubs o amigos")
            }
            .background(TrazoColors.background)
            .navigationBarHidden(true)
            .toolbarBackground(.hidden, for: .tabBar)
            .navigationDestination(for: RunningClub.self) { club in
                ClubChatView(club: club)
            }
            .navigationDestination(item: Binding(
                get: { navigation.clubToOpen },
                set: { navigation.clubToOpen = $0 }
            )) { club in
                ClubChatView(club: club)
            }
            .sheet(isPresented: $showsCreateClub) {
                CreateClubSheet()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showsJoinClub, onDismiss: {
                navigation.clearPendingJoin()
            }) {
                JoinClubSheet(prefilledCode: navigation.pendingJoinInviteCode ?? "")
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .onAppear {
                CommunitySeedService.seedIfNeeded(in: modelContext)
                presentJoinSheetIfNeeded()
            }
            .onChange(of: navigation.pendingJoinInviteCode) { _, _ in
                presentJoinSheetIfNeeded()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.md) {
            HStack {
                Text("Comunidad")
                    .font(TrazoTypography.largeTitle())
                    .foregroundStyle(TrazoColors.textPrimary)

                Spacer()

                Button {
                    showsJoinClub = true
                } label: {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(TrazoColors.mutedTeal)
                }
                .accessibilityLabel("Unirse a un club")

                Button {
                    showsCreateClub = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(TrazoColors.routeTeal)
                }
                .accessibilityLabel("Crear club")
            }

            Text("Running Clubs, chats y Trazos en grupo")
                .font(TrazoTypography.body())
                .foregroundStyle(TrazoColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, TrazoSpacing.lg)
        .safeAreaPadding(.top, TrazoSpacing.md)
        .padding(.bottom, TrazoSpacing.md)
        .background(TrazoColors.surface)
    }

    @ViewBuilder
    private func pinnedClubCard(_ club: RunningClub) -> some View {
        TrazoCard {
            VStack(spacing: TrazoSpacing.md) {
                NavigationLink(value: club) {
                    clubRowContent(club)
                }
                .buttonStyle(.plain)

                if searchText.isEmpty {
                    Divider()
                        .overlay(TrazoColors.mutedTeal.opacity(0.35))

                    NavigationLink {
                        ClubLeaderboardView(club: club)
                    } label: {
                        LeaderboardPreviewSection(club: club)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(TrazoTypography.caption())
            .foregroundStyle(TrazoColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, TrazoSpacing.sm)
    }

    private func clubRow(_ club: RunningClub, isPinned: Bool) -> some View {
        Group {
            if isPinned {
                TrazoCard {
                    clubRowContent(club)
                }
            } else {
                clubRowContent(club)
                    .padding(.vertical, TrazoSpacing.sm)
            }
        }
    }

    private func clubRowContent(_ club: RunningClub) -> some View {
        HStack(spacing: TrazoSpacing.md) {
            TrazoAvatar(initials: club.initials, color: club.accent.color)

            VStack(alignment: .leading, spacing: TrazoSpacing.xs) {
                HStack(spacing: TrazoSpacing.sm) {
                    Text(club.name)
                        .font(TrazoTypography.headline())
                        .foregroundStyle(TrazoColors.textPrimary)

                    if club.isPinned {
                        Text("Fijado")
                            .font(.caption2.bold())
                            .foregroundStyle(TrazoColors.routeTeal)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(TrazoColors.routeTeal.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                Text(club.lastMessage)
                    .font(TrazoTypography.caption())
                    .foregroundStyle(TrazoColors.textSecondary)
                    .lineLimit(1)

                Text("\(club.memberCount) miembros")
                    .font(.caption2)
                    .foregroundStyle(TrazoColors.mutedTeal)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: TrazoSpacing.xs) {
                Text(club.lastMessageTime)
                    .font(TrazoTypography.caption())
                    .foregroundStyle(TrazoColors.textSecondary)

                if club.unreadCount > 0 {
                    Text("\(club.unreadCount)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .frame(minWidth: 22, minHeight: 22)
                        .padding(.horizontal, club.unreadCount > 9 ? 4 : 0)
                        .background(TrazoColors.routeTeal)
                        .clipShape(Circle())
                }
            }
        }
    }

    private func presentJoinSheetIfNeeded() {
        guard navigation.pendingJoinInviteCode != nil else { return }
        showsJoinClub = true
    }

    private var emptySearchState: some View {
        VStack(spacing: TrazoSpacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(TrazoColors.mutedTeal)

            Text("Sin resultados")
                .font(TrazoTypography.headline())
                .foregroundStyle(TrazoColors.textPrimary)

            Text("Prueba con otro nombre de club o crea uno nuevo.")
                .font(TrazoTypography.caption())
                .foregroundStyle(TrazoColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, TrazoSpacing.xl)
    }
}

#Preview {
    CommunityHomeView()
        .modelContainer(for: [
            RunningClub.self,
            ClubMember.self,
            ClubMessage.self,
            ClubInvitation.self,
            RouteProposal.self,
            RouteVote.self,
        ], inMemory: true)
}
