import SwiftUI

// MARK: - Glass Container

/// Replaces `.background(textBackgroundColor)` + `.clipShape(RoundedRectangle(cornerRadius: 8))`
/// + `.overlay(RoundedRectangle(cornerRadius: 8).stroke(...))`
struct GlassContainerModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Glass Toolbar

/// Replaces `.background(Color(nsColor: .controlBackgroundColor))`
struct GlassToolbarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .glassEffect(.regular, in: Rectangle())
    }
}

// MARK: - Glass Banner

/// Replaces `.background(color.opacity(0.1))` + `.clipShape(RoundedRectangle(cornerRadius: ...))`
struct GlassBannerModifier: ViewModifier {
    let tint: Color

    func body(content: Content) -> some View {
        content
            .glassEffect(.regular.tint(tint), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - View Extensions

extension View {
    func glassContainer() -> some View {
        modifier(GlassContainerModifier())
    }

    func glassToolbar() -> some View {
        modifier(GlassToolbarModifier())
    }

    func glassBanner(tint: Color) -> some View {
        modifier(GlassBannerModifier(tint: tint))
    }
}
