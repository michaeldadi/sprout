import SwiftUI

/// Existing auth control, extracted without changing its call-site contract.
/// The color parameters remain until the auth screens migrate to semantic roles.
struct SocialLoginButton: View {
    let icon: String
    let text: String
    let backgroundColor: Color
    var textColor: Color = .white
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if icon == "google" {
                    Image("GoogleLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .accessibilityHidden(true)
                }
                Text(text)
                    .font(SproutType.body.weight(.medium))
                    .multilineTextAlignment(.center)
            }
            .foregroundColor(textColor)
            .padding(.horizontal, SproutSpacing.screen)
            .frame(maxWidth: .infinity, minHeight: SproutSpacing.touchTarget)
            .padding(.vertical, SproutSpacing.xs)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: SproutShape.control))
        }
        .buttonStyle(.plain)
    }
}
