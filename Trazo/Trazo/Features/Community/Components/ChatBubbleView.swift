import SwiftUI

struct ChatBubbleView: View {
    let message: ClubMessage

    var body: some View {
        HStack {
            if message.isFromCurrentUser { Spacer(minLength: 48) }

            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: TrazoSpacing.xs) {
                if !message.isFromCurrentUser {
                    Text(message.senderName)
                        .font(TrazoTypography.caption())
                        .foregroundStyle(TrazoColors.textSecondary)
                }

                Text(message.text)
                    .font(TrazoTypography.body())
                    .foregroundStyle(message.isFromCurrentUser ? .white : TrazoColors.textPrimary)
                    .padding(.horizontal, TrazoSpacing.lg)
                    .padding(.vertical, TrazoSpacing.md)
                    .background(message.isFromCurrentUser ? TrazoColors.bubbleOutgoing : TrazoColors.bubbleIncoming)
                    .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.bubble, style: .continuous))

                Text(message.formattedTime)
                    .font(TrazoTypography.caption())
                    .foregroundStyle(TrazoColors.textSecondary)
            }

            if !message.isFromCurrentUser { Spacer(minLength: 48) }
        }
    }
}
