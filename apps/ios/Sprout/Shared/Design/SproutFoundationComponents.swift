import SwiftUI

enum SproutActionRole {
    case primary, secondary, quiet, destructive
}

struct SproutActionButton: View {
    let title: String
    var role: SproutActionRole = .primary
    var isBusy = false
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SproutSpacing.xs) {
                if isBusy { ProgressView().tint(SproutColor.textSecondary) }
                Text(title).multilineTextAlignment(.center)
            }
            .font(SproutType.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: SproutSpacing.touchTarget)
        }
        .buttonStyle(SproutActionButtonStyle(role: role))
        .disabled(!isEnabled || isBusy)
        .accessibilityValue(isBusy ? "Loading" : "")
    }
}

private struct SproutActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let role: SproutActionRole

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .padding(.horizontal, SproutSpacing.md)
            .background(background, in: RoundedRectangle(cornerRadius: SproutShape.control))
            .overlay {
                if isEnabled && role == .secondary {
                    RoundedRectangle(cornerRadius: SproutShape.control)
                        .stroke(SproutColor.separator, lineWidth: 1)
                }
            }
            .opacity(configuration.isPressed ? 0.88 : 1)
    }

    private var foreground: Color {
        guard isEnabled else { return SproutColor.textSecondary }
        return switch role {
        case .primary: SproutColor.onAction
        case .destructive: SproutColor.error
        case .secondary, .quiet: SproutColor.action
        }
    }

    private var background: Color {
        guard isEnabled else { return SproutColor.surfaceSubtle }
        return switch role {
        case .primary: SproutColor.action
        case .secondary: SproutColor.surface
        case .quiet: SproutColor.canvas
        case .destructive: SproutColor.surfaceSubtle
        }
    }
}

/// A display component; the caller supplies a source amount and currency code.
struct SproutAmountText: View {
    let amount: Decimal?
    let currencyCode: String
    var isLarge = false
    var isConcealed = false

    private var formatted: String {
        guard let amount else { return "Amount unavailable" }
        return NumberFormatter.sproutCurrency(code: currencyCode, amount: amount).string(from: amount as NSDecimalNumber)
            ?? "Amount unavailable"
    }

    var body: some View {
        Text(isConcealed ? "••••••" : formatted)
            .font(isLarge ? .system(.largeTitle, design: .default, weight: .semibold) : .system(.headline, design: .default, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(SproutColor.textPrimary)
            .lineLimit(nil)
            .minimumScaleFactor(1)
            .accessibilityLabel(isConcealed ? "Amount hidden" : formatted)
    }
}

private extension NumberFormatter {
    static func sproutCurrency(code: String, amount: Decimal) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        formatter.currencyCode = code
        let parts = (amount as NSDecimalNumber).stringValue.lowercased().split(separator: "e", maxSplits: 1)
        let fractionDigits = parts[0].split(separator: ".", maxSplits: 1).dropFirst().first?.count ?? 0
        let exponent = parts.count == 2 ? Int(parts[1]) ?? 0 : 0
        formatter.maximumFractionDigits = max(formatter.maximumFractionDigits, max(0, fractionDigits - exponent))
        return formatter
    }
}

enum SproutFeedbackKind {
    case info, warning, error, success

    var color: Color {
        switch self {
        case .info: SproutColor.info
        case .warning: SproutColor.warning
        case .error: SproutColor.error
        case .success: SproutColor.success
        }
    }

    var symbol: String {
        switch self {
        case .info: "info.circle"
        case .warning: "exclamationmark.triangle"
        case .error: "xmark.circle"
        case .success: "checkmark.circle"
        }
    }
}

struct SproutStatusBanner: View {
    let title: String
    let detail: String
    let kind: SproutFeedbackKind

    var body: some View {
        HStack(alignment: .top, spacing: SproutSpacing.sm) {
            Image(systemName: kind.symbol).foregroundStyle(kind.color).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: SproutSpacing.xxs) {
                Text(title).font(SproutType.rowTitle).foregroundStyle(SproutColor.textPrimary)
                Text(detail).font(SproutType.detail).foregroundStyle(SproutColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(SproutSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SproutColor.surfaceSubtle, in: RoundedRectangle(cornerRadius: SproutShape.surface))
        .accessibilityElement(children: .combine)
    }
}

/// Compact status for a list or summary when the affected records carry their own detail.
struct SproutStatusLine: View {
    let text: String
    let kind: SproutFeedbackKind

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SproutSpacing.xs) {
            Image(systemName: kind.symbol)
                .foregroundStyle(kind.color)
                .accessibilityHidden(true)
            Text(text)
                .font(SproutType.detail)
                .foregroundStyle(SproutColor.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct SproutTransactionRow: View {
    let title: String
    let detail: String
    let amount: Decimal?
    let currencyCode: String
    var status: String? = nil
    var statusKind: SproutFeedbackKind = .warning
    var isSelected = false
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Group {
            if isEnabled {
                Button(action: action) { rowContent }
                    .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var rowContent: some View {
        VStack(alignment: .trailing, spacing: SproutSpacing.xs) {
            HStack(alignment: .top, spacing: SproutSpacing.sm) {
                Image(systemName: "creditcard")
                    .foregroundStyle(SproutColor.action)
                    .frame(width: 36, height: 36)
                    .background(SproutColor.actionSubtle, in: RoundedRectangle(cornerRadius: SproutShape.control))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: SproutSpacing.xxs) {
                    Text(title).font(SproutType.rowTitle).foregroundStyle(SproutColor.textPrimary)
                    Text(detail).font(SproutType.detail).foregroundStyle(SproutColor.textSecondary)
                    if let status { Text(status).font(SproutType.label).foregroundStyle(statusKind.color) }
                }
                Spacer(minLength: 0)
            }
            SproutAmountText(amount: amount, currencyCode: currencyCode)
                .multilineTextAlignment(.trailing)
        }
        .padding(SproutSpacing.md)
        .frame(maxWidth: .infinity, minHeight: SproutSpacing.rowMinHeight)
        .background(isSelected ? SproutColor.actionSubtle : SproutColor.surface,
                    in: RoundedRectangle(cornerRadius: SproutShape.surface))
    }
}

struct SproutStatePanel: View {
    let title: String
    let detail: String
    var kind: SproutFeedbackKind = .info
    var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: SproutSpacing.xs) {
            if isLoading { ProgressView().accessibilityHidden(true) }
            Text(title).font(SproutType.sectionTitle).foregroundStyle(SproutColor.textPrimary)
            Text(detail).font(SproutType.detail).foregroundStyle(SproutColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SproutSpacing.lg)
        .background(SproutColor.surface, in: RoundedRectangle(cornerRadius: SproutShape.surface))
        .accessibilityElement(children: .combine)
    }
}

struct SproutInputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var helper: String? = nil
    var error: String? = nil
    var isSecure = false

    var body: some View {
        VStack(alignment: .leading, spacing: SproutSpacing.xs) {
            Text(title).font(SproutType.label).foregroundStyle(SproutColor.textPrimary)
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text,
                              prompt: Text(placeholder).foregroundColor(SproutColor.textSecondary))
                }
            }
            .font(SproutType.body)
            .foregroundStyle(SproutColor.textPrimary)
            .padding(.horizontal, SproutSpacing.md)
            .frame(minHeight: 48)
            .background(SproutColor.surface, in: RoundedRectangle(cornerRadius: SproutShape.control))
            .overlay(RoundedRectangle(cornerRadius: SproutShape.control)
                .stroke(error == nil ? SproutColor.separator : SproutColor.error, lineWidth: 1))
            if let error {
                Text(error).font(SproutType.detail).foregroundStyle(SproutColor.error)
            } else if let helper {
                Text(helper).font(SproutType.detail).foregroundStyle(SproutColor.textSecondary)
            }
        }
    }
}

struct SproutSearchField: View {
    let title: String
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: SproutSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(SproutColor.textSecondary)
                .accessibilityHidden(true)
            TextField(
                title,
                text: $text,
                prompt: Text("Merchant or category").foregroundColor(SproutColor.textSecondary)
            )
            .focused($isFocused)
            .submitLabel(.search)
            .onSubmit { isFocused = false }
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .accessibilityLabel(title)
            .accessibilityIdentifier("activity.search")
            if !text.isEmpty {
                Button {
                    text = ""
                    isFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(SproutColor.textSecondary)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .font(SproutType.body)
        .padding(.leading, SproutSpacing.md)
        .padding(.trailing, text.isEmpty ? SproutSpacing.md : SproutSpacing.xxs)
        .frame(minHeight: 48)
        .background(SproutColor.surface, in: RoundedRectangle(cornerRadius: SproutShape.control))
        .overlay(RoundedRectangle(cornerRadius: SproutShape.control)
            .stroke(SproutColor.separator, lineWidth: 1))
    }
}
