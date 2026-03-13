//
//  PhotoScanView.swift
//  FluffyList
//
//  Created by David Albert on 2/22/26.
//

import SwiftUI
import AVFoundation
import os

/// Multi-page photo scanning view for cookbook recipes.
/// After capturing the first photo, the user can add more pages (up to 5),
/// remove bad photos, and then send all pages for recipe extraction.
struct PhotoScanView: View {
    @State private var pages: [UIImage]
    let onDone: ([UIImage]) -> Void
    let onCancel: () -> Void

    @State private var showingCamera = false
    @State private var showingCameraPermissionDenied = false

    /// Maximum pages allowed per scan — enough for any cookbook recipe.
    private let maxPages = 5

    init(initialPages: [UIImage], onDone: @escaping ([UIImage]) -> Void, onCancel: @escaping () -> Void) {
        _pages = State(initialValue: initialPages)
        self.onDone = onDone
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Page count header
                if pages.count == 1 {
                    Text("1 page scanned")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(pages.count) pages scanned")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                // Thumbnail strip
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { index, image in
                            thumbnailCard(image: image, pageNumber: index + 1) {
                                withAnimation { _ = pages.remove(at: index) }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 190)

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    if pages.count < maxPages {
                        Button {
                            requestCameraAccess()
                        } label: {
                            Label("Add Page", systemImage: "camera.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    } else {
                        Text("Maximum \(maxPages) pages reached")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        onDone(pages)
                    } label: {
                        Text("Done Scanning")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(pages.isEmpty)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Scan Pages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: scanToolbar)
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView { image in
                    if let image {
                        pages.append(image)
                        Logger.importPipeline.debug("Added page — now \(pages.count, privacy: .public) page(s)")
                    } else {
                        Logger.importPipeline.debug("Add-page camera cancelled")
                    }
                    showingCamera = false
                }
                .ignoresSafeArea()
            }
            .alert("Camera Access Required", isPresented: $showingCameraPermissionDenied) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("FluffyList needs camera access to scan recipes. You can enable it in Settings.")
            }
        }
    }

    @ToolbarContentBuilder
    private func scanToolbar() -> some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { onCancel() }
        }
    }

    /// Check camera permission before presenting the camera.
    /// Uses Task + await so the state update runs on @MainActor
    /// (DispatchQueue.main.async doesn't guarantee @MainActor isolation).
    private func requestCameraAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showingCamera = true
        case .notDetermined:
            Task {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                if granted {
                    showingCamera = true
                } else {
                    showingCameraPermissionDenied = true
                }
            }
        case .denied, .restricted:
            showingCameraPermissionDenied = true
        @unknown default:
            showingCameraPermissionDenied = true
        }
    }

    /// A single thumbnail card with page number badge and remove button.
    @ViewBuilder
    private func thumbnailCard(image: UIImage, pageNumber: Int, onRemove: @escaping () -> Void) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 120, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.secondary.opacity(0.3), lineWidth: 1)
                )
                .overlay(alignment: .bottomLeading) {
                    // Page number badge
                    Text("Page \(pageNumber)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.blue))
                        .padding(6)
                }

            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .red)
            }
            .offset(x: 6, y: -6)
        }
    }
}

#Preview {
    PhotoScanView(
        initialPages: [],
        onDone: { _ in },
        onCancel: { }
    )
}
