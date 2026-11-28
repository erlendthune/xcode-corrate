import SwiftUI
import UIKit

/// SwiftUI can disable sheet dismissal but has no callback for an attempted drag.
struct WorkoutDismissalGuard: UIViewControllerRepresentable {
    let hasUnsavedChanges: Bool
    let onAttempt: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(hasUnsavedChanges: hasUnsavedChanges, onAttempt: onAttempt)
    }

    func makeUIViewController(context: Context) -> ProbeController {
        let controller = ProbeController()
        controller.view.backgroundColor = .clear
        controller.onAppear = { [weak controller, weak coordinator = context.coordinator] in
            if let controller { coordinator?.attach(to: controller) }
        }
        return controller
    }

    func updateUIViewController(_ controller: ProbeController, context: Context) {
        context.coordinator.hasUnsavedChanges = hasUnsavedChanges
        context.coordinator.onAttempt = onAttempt
        DispatchQueue.main.async { [weak controller, weak coordinator = context.coordinator] in
            if let controller { coordinator?.attach(to: controller) }
        }
    }

    final class ProbeController: UIViewController {
        var onAppear: (() -> Void)?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            onAppear?()
        }
    }

    final class Coordinator: NSObject, UIAdaptivePresentationControllerDelegate {
        var hasUnsavedChanges: Bool
        var onAttempt: () -> Void
        private weak var previousDelegate: UIAdaptivePresentationControllerDelegate?
        private weak var presentation: UIPresentationController?

        init(hasUnsavedChanges: Bool, onAttempt: @escaping () -> Void) {
            self.hasUnsavedChanges = hasUnsavedChanges
            self.onAttempt = onAttempt
        }

        func attach(to controller: UIViewController) {
            var candidate: UIViewController? = controller
            while let current = candidate {
                if current.presentingViewController != nil, let presentation = current.presentationController {
                    if presentation.delegate !== self {
                        if self.presentation?.delegate === self { self.presentation?.delegate = previousDelegate }
                        self.presentation = presentation
                        previousDelegate = presentation.delegate
                        presentation.delegate = self
                    }
                    return
                }
                candidate = current.parent
            }
        }

        func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
            !hasUnsavedChanges && (previousDelegate?.presentationControllerShouldDismiss?(presentationController) ?? true)
        }

        func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
            if hasUnsavedChanges { onAttempt() }
            else { previousDelegate?.presentationControllerDidAttemptToDismiss?(presentationController) }
        }

        func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
            previousDelegate?.presentationControllerWillDismiss?(presentationController)
        }

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            previousDelegate?.presentationControllerDidDismiss?(presentationController)
        }
    }
}