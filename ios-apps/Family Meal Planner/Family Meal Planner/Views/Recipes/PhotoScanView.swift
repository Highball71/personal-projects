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
    // NOTE: initialPages is stored as a `let` and synced to `pages` via
    // .onAppear. We intentionally do NOT use `State(initialValue:)` here
    // because @State is only initialised once per view identity — if
    // SwiftUI evaluates the sheet content closure before scannedPages is
    // populated (e.g. during an earlier body render), the state captures
    // the stale empty array and ignores later re-creations. Reading
    // `initialPages` in onAppear guarantees we see the current value.
    let initialPages: [UIImage]
    let onDone: ([UIImage]) -> Void
    let onCancel: () -> Void

    @State private var pages: [UIImage] = []
    @State private var hasInitializedPages = false
    @State private var showingCamera = false
    @State private var showingCameraPermissionDenied = false

    /// Maximum pages allowed per scan — enough for any cookbook recipe.
    private let maxPages = 5

    init(initialPages: [UIImage], onDone: @escaping ([UIImage]) -> Void, onCancel: @escaping () -> Void) {
        self.initialPages = initialPages
        self.onDone = onDone
        self.onCancel = onCancel
        Logger.importPipeline.info("PhotoScanView init: initialPages count=\(initialPages.count, privacy: .public)")
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
            .onAppear {
                Logger.importPipeline.info("PhotoScanView onAppear: initialPages=\(initialPages.count, privacy: .public), pages=\(pages.count, privacy: .public), hasInitialized=\(hasInitializedPages, privacy: .public)")
                // Sync from initialPages the first time the view appears.
                // This avoids the @State init-only-once trap where the state
                // captures an empty array before the real pages arrive.
                guard !hasInitializedPages else { return }
                pages = initialPages
                hasInitializedPages = true
                Logger.importPipeline.info("PhotoScanView pages synced from initialPages — pages now=\(pages.count, privacy: .public)")
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
