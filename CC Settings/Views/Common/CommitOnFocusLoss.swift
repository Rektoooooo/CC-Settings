import SwiftUI

/// Runs `commit` when the user finishes editing a text field: on Return, when focus moves
/// elsewhere, or when the view goes away while still focused (so navigating to another
/// section never loses what was typed). Nothing is committed per keystroke, which also
/// stops a save-triggered reload from rewriting the field under the cursor.
///
/// `value` is the field's text. The commit only fires if it changed since the field gained
/// focus, so tabbing through a field never rewrites the config file.
struct CommitOnFocusLoss<Value: Equatable>: ViewModifier {
    let value: Value
    let commit: () -> Void
    @FocusState private var isFocused: Bool
    @State private var baseline: Value?

    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .onSubmit { fireIfChanged() }
            .onChange(of: isFocused) { _, nowFocused in
                if nowFocused {
                    baseline = value
                } else {
                    fireIfChanged()
                    baseline = nil
                }
            }
            .onDisappear {
                if isFocused { fireIfChanged() }
            }
    }

    private func fireIfChanged() {
        guard let baseline, baseline != value else { return }
        commit()
        self.baseline = value
    }
}

extension View {
    /// See `CommitOnFocusLoss`.
    func commitOnFocusLoss<Value: Equatable>(of value: Value, _ commit: @escaping () -> Void) -> some View {
        modifier(CommitOnFocusLoss(value: value, commit: commit))
    }
}
