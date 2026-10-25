//
//  DismissKeyboardOnTap.swift
//  AstroAI
//

import SwiftUI
import UIKit

extension View {
    /// A tap anywhere outside a text field hides the keyboard. Buttons, scrolling, and the field itself still receive the touch.
    func dismissKeyboardOnTap() -> some View {
        background {
            KeyboardDismissInstaller()
        }
    }
}

private struct KeyboardDismissInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> KeyboardDismissAnchor {
        let view = KeyboardDismissAnchor()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: KeyboardDismissAnchor, context: Context) {}
}

private final class KeyboardDismissAnchor: UIView {
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let window else { return }
        KeyboardDismissTap.install(on: window)
    }
}

private final class KeyboardDismissTap: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismissTap()
    private static let gestureName = "dismissKeyboardOnTap"
    /// Covers the padding drawn around a field, so a tap on the field chrome does not dismiss it.
    private static let fieldSlop = CGSize(width: 20, height: 16)

    static func install(on window: UIWindow) {
        if window.gestureRecognizers?.contains(where: { $0.name == gestureName }) == true { return }
        let tap = UITapGestureRecognizer(target: shared, action: #selector(dismiss(_:)))
        tap.name = gestureName
        tap.cancelsTouchesInView = false
        tap.delaysTouchesBegan = false
        tap.delaysTouchesEnded = false
        tap.delegate = shared
        window.addGestureRecognizer(tap)
    }

    @objc private func dismiss(_ gesture: UITapGestureRecognizer) {
        resignFirstResponder()
        // SwiftUI can restore focus in the same turn. Resign again after that pass.
        Task { @MainActor [weak self] in
            self?.resignFirstResponder()
        }
    }

    private func resignFirstResponder() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let window = gestureRecognizer.view as? UIWindow else { return false }
        let point = touch.location(in: window)
        var isEditing = false
        if touchesTextInput(window, at: point, isEditing: &isEditing) { return false }
        return isEditing
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    private func touchesTextInput(_ view: UIView, at point: CGPoint, isEditing: inout Bool) -> Bool {
        if view.isFirstResponder { isEditing = true }
        guard !view.isHidden, view.alpha > 0.01 else { return false }
        if view is UITextField || view is UITextView {
            guard view.bounds.width > 1, view.bounds.height > 1, let window = view.window else { return false }
            let frame = view.convert(view.bounds, to: window).insetBy(dx: -Self.fieldSlop.width, dy: -Self.fieldSlop.height)
            return frame.contains(point)
        }
        for subview in view.subviews {
            if touchesTextInput(subview, at: point, isEditing: &isEditing) { return true }
        }
        return false
    }
}
