import SwiftUI

/// Semantic roles backed by light/dark colors in Assets.xcassets.
/// AccentColor aliases action for controls that still use the system accent.
enum SproutColor {
    static let canvas = Color("SproutCanvas")
    static let surface = Color("SproutSurface")
    static let surfaceSubtle = Color("SproutSurfaceSubtle")
    static let textPrimary = Color("SproutTextPrimary")
    static let textSecondary = Color("SproutTextSecondary")
    static let separator = Color("SproutSeparator")
    static let action = Color("SproutAction")
    static let onAction = Color("SproutOnAction")
    static let actionSubtle = Color("SproutActionSubtle")
    static let success = Color("SproutSuccess")
    static let warning = Color("SproutWarning")
    static let error = Color("SproutError")
    static let info = Color("SproutInfo")
}

enum SproutSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let screen: CGFloat = 20
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let rowMinHeight: CGFloat = 56
    static let touchTarget: CGFloat = 44
}

enum SproutType {
    static let screenTitle = Font.system(.largeTitle, design: .default, weight: .semibold)
    static let sectionTitle = Font.system(.title3, design: .default, weight: .semibold)
    static let rowTitle = Font.system(.body, design: .default, weight: .medium)
    static let body = Font.system(.body)
    static let detail = Font.system(.subheadline)
    static let label = Font.system(.caption, design: .default, weight: .medium)
}

enum SproutShape {
    static let control: CGFloat = 12
    static let surface: CGFloat = 16
    static let featured: CGFloat = 24
}
