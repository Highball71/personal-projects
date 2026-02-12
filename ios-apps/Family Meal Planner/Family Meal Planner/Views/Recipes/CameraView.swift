//
//  CameraView.swift
//  Family Meal Planner
//

import SwiftUI
import UIKit

/// Wraps UIImagePickerController to provide camera access from SwiftUI.
/// SwiftUI's PhotosPicker only handles the photo library, not the camera,
/// so we need this UIViewControllerRepresentable wrapper.
struct CameraView: UIViewControllerRepresentable {
    /// Called with the captured image, or nil if the user cancelled.
    var onImageCaptured: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageCaptured: onImageCaptured)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImageCaptured: (UIImage?) -> Void

        init(onImageCaptured: @escaping (UIImage?) -> Void) {
            self.onImageCaptured = onImageCaptured
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = info[.originalImage] as? UIImage
            print("[PhotoScan] Camera captured image: \(image != nil ? "yes" : "no")")
            // Don't call picker.dismiss() — SwiftUI handles dismissal
            // via the fullScreenCover's isPresented binding. Calling both
            // causes a race condition that can swallow the callback.
            onImageCaptured(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            print("[PhotoScan] Camera cancelled")
            onImageCaptured(nil)
        }
    }
}
