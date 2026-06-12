import SwiftData
import SwiftUI

struct ClubChatView: View {
    @Bindable var club: RunningClub

    @Environment(\.modelContext) private var modelContext
    @Environment(\.currentUserProfile) private var currentUserProfile

    @State private var draftMessage = ""
    @State private var showsInviteSheet = false
    @State private var showsProposeSheet = false
    @State private var showsRouletteSheet = false

    private var sortedMessages: [ClubMessage] {
        club.messages.sorted { $0.timestamp < $1.timestamp }
    }

    private var canSpinRoulette: Bool {
        club.openProposals.count >= 2
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: TrazoSpacing.md) {
                        clubInfoBanner
                        proposalsSection
                        winnerBanner

                        ForEach(sortedMessages) { message in
                            ChatBubbleView(message: message)
                                .id(message.persistentModelID)
                        }
                    }
                    .padding(TrazoSpacing.lg)
                }
                .onAppear {
                    club.unreadCount = 0
                    scrollToBottom(proxy: proxy)
                    Task {
                        await syncRemoteMessages()
                        await CommunityRealtimeService.shared.subscribe(
                            clubSlug: club.slug,
                            modelContext: modelContext,
                            club: club
                        )
                    }
                }
                .onDisappear {
                    Task { await CommunityRealtimeService.shared.unsubscribe() }
                }
                .onChange(of: sortedMessages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: club.proposals.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
            }

            messageComposer
        }
        .background(TrazoColors.background)
        .navigationTitle(club.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink {
                    ClubLeaderboardView(club: club)
                } label: {
                    Image(systemName: "trophy.fill")
                }
                .accessibilityLabel("Leaderboard")

                Button {
                    showsProposeSheet = true
                } label: {
                    Image(systemName: "map")
                }
                .accessibilityLabel("Proponer Trazo")

                if canSpinRoulette {
                    Button {
                        showsRouletteSheet = true
                    } label: {
                        Image(systemName: "dice.fill")
                    }
                    .accessibilityLabel("Ruleta")
                }

                Button {
                    showsInviteSheet = true
                } label: {
                    Image(systemName: "person.badge.plus")
                }
                .accessibilityLabel("Invitar")
            }
        }
        .sheet(isPresented: $showsInviteSheet) {
            InviteFriendsSheet(club: club)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showsProposeSheet) {
            ProposeTrazoSheet(club: club)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showsRouletteSheet) {
            TrazoRouletteSheet(club: club)
                .presentationDetents([.large])
        }
    }

    private var clubInfoBanner: some View {
        TrazoCard {
            HStack(spacing: TrazoSpacing.md) {
                TrazoAvatar(initials: club.initials, color: club.accent.color)

                VStack(alignment: .leading, spacing: TrazoSpacing.xs) {
                    Text("\(club.memberCount) miembros")
                        .font(TrazoTypography.caption())
                        .foregroundStyle(TrazoColors.textSecondary)

                    Text("Código: \(club.inviteCode)")
                        .font(TrazoTypography.caption())
                        .foregroundStyle(TrazoColors.routeTeal)
                }

                Spacer()

                Button("Invitar") {
                    showsInviteSheet = true
                }
                .font(TrazoTypography.caption())
                .foregroundStyle(TrazoColors.routeTeal)
            }
        }
    }

    @ViewBuilder
    private var proposalsSection: some View {
        if !club.openProposals.isEmpty {
            VStack(alignment: .leading, spacing: TrazoSpacing.md) {
                HStack {
                    Text("Trazos propuestos")
                        .font(TrazoTypography.headline())
                        .foregroundStyle(TrazoColors.textPrimary)

                    Spacer()

                    if canSpinRoulette {
                        Button("Ruleta 🎲") {
                            showsRouletteSheet = true
                        }
                        .font(TrazoTypography.caption())
                        .foregroundStyle(TrazoColors.accentOrange)
                    }
                }

                ForEach(club.openProposals) { proposal in
                    RouteProposalCard(
                        proposal: proposal,
                        hasVoted: CommunityRouteService.hasUserVoted(for: proposal)
                    ) {
                        vote(for: proposal)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var winnerBanner: some View {
        if let winner = club.resolvedWinner {
            TrazoCard {
                HStack(spacing: TrazoSpacing.md) {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(TrazoColors.accentOrange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Trazo del club")
                            .font(TrazoTypography.caption())
                            .foregroundStyle(TrazoColors.textSecondary)
                        Text(winner.title)
                            .font(TrazoTypography.headline())
                            .foregroundStyle(TrazoColors.textPrimary)
                    }

                    Spacer()
                }
            }
        }
    }

    private var messageComposer: some View {
        HStack(spacing: TrazoSpacing.md) {
            Button {
                showsProposeSheet = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(TrazoColors.routeTeal)
            }
            .accessibilityLabel("Proponer Trazo")

            TextField("Mensaje...", text: $draftMessage, axis: .vertical)
                .font(TrazoTypography.body())
                .lineLimit(1...4)
                .padding(.horizontal, TrazoSpacing.lg)
                .padding(.vertical, TrazoSpacing.md)
                .background(TrazoColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.lg, style: .continuous))

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(draftMessage.trimmingCharacters(in: .whitespaces).isEmpty ? TrazoColors.mutedTeal : TrazoColors.routeTeal)
            }
            .disabled(draftMessage.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(TrazoSpacing.lg)
        .background(TrazoColors.elevated)
    }

    private func vote(for proposal: RouteProposal) {
        let voterName = currentUserProfile?.displayName.nilIfEmpty ?? "Tú"
        CommunityRouteService.castVote(
            for: proposal,
            club: club,
            voterName: voterName,
            in: modelContext
        )
    }

    private func sendMessage() {
        let text = draftMessage.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        let senderName = currentUserProfile?.displayName.nilIfEmpty ?? "Tú"
        let message = ClubMessage(
            senderName: senderName,
            text: text,
            timestamp: .now,
            isFromCurrentUser: true,
            club: club
        )
        modelContext.insert(message)
        club.lastMessageText = text
        club.lastMessageAt = .now
        draftMessage = ""
        try? modelContext.save()

        Task {
            try? await CommunityRemoteService.shared.sendMessage(
                clubSlug: club.slug,
                senderName: senderName,
                text: text,
                isFromCurrentUser: true
            )
        }
    }

    private func syncRemoteMessages() async {
        let lastDate = club.messages.map(\.timestamp).max()
        guard let remoteMessages = try? await CommunityRemoteService.shared.fetchMessages(
            clubSlug: club.slug,
            after: lastDate
        ) else { return }

        for item in remoteMessages {
            guard !club.messages.contains(where: { $0.text == item.text && $0.senderName == item.senderName }) else { continue }
            let message = ClubMessage(
                senderName: item.senderName,
                text: item.text,
                timestamp: item.timestamp,
                isFromCurrentUser: item.isFromCurrentUser,
                club: club
            )
            modelContext.insert(message)
        }

        if let last = remoteMessages.last {
            club.lastMessageText = last.text
            club.lastMessageAt = last.timestamp
        }

        try? modelContext.save()
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastMessage = sortedMessages.last else { return }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastMessage.persistentModelID, anchor: .bottom)
            }
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
