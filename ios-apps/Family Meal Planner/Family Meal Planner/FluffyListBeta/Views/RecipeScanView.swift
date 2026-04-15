//
//  RecipeScanView.swift
//  FluffyList
//
//  Figma-styled multi-page recipe photo scanner.
//  Dark near-black background, live camera viewfinder with corner
//  bracket guides, animated amber scan line, page counter, shutter
//  button, thumbnail strip, and Done button.
//

import AVFoundation
import Combine
import SwiftUI

struct RecipeScanView: View {
    let onDone: ([UIImage]) -> Void
    let onCancel: () -> Void

    @StateObject private var camera = CameraCaptureManager()
    @State private var pages: [UIImage] = []
    @State private var scanLineOffset: CGFloat = 0
    @State private var showingPermissionDenied = false

    private let maxPages = 5
    private let viewfinderAspect: CGFloat = 4 / 3

    // MARK: - Body

    var body: some View {
        ZStack {
            // Dark background
            Color(hex: "111111").ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                // Viewfinder
                GeometryReader { geo in
                    let width = geo.size.width - 40
                    let height = width * viewfinderAspect
                    ZStack {
                        // Camera preview
                        CameraPreviewRepresentable(session: camera.session)
                            .frame(width: width, height: height)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        // Corner bracket guides
                        cornerBrackets(size: CGSize(width: width, height: height))

                        // Animated amber scan line
                        Rectangle()
                            .fill(Color.fluffyAmber.opacity(0.6))
                            .frame(width: width - 32, height: 2)
                            .offset(y: scanLineOffset)
                    }
                    .frame(width: width, height: height)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 12)

                // Thumbnail strip
                if !pages.isEmpty {
                    thumbnailStrip
                        .padding(.bottom, 8)
                }

                // Shutter + controls
                shutterArea
                    .padding(.bottom, 32)
            }
        }
        .onAppear {
            checkPermissionAndStart()
            startScanLineAnimation()
        }
        .onDisappear {
            camera.stop()
        }
        .alert("Camera Access Required", isPresented: $showingPermissionDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { onCancel() }
        } message: {
            Text("FluffyList needs camera access to scan recipes. Enable it in Settings.")
        }
        .onReceive(camera.capturedImage) { image in
            pages.append(image)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button { onCancel() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
            }

            Spacer()

            Text(pageCountText)
                .font(.fluffySubheadline)
                .foregroundStyle(.white.opacity(0.8))

            Spacer()

            Button {
                camera.stop()
                onDone(pages)
            } label: {
                Text("Done")
                    .font(.fluffyButton)
                    .foregroundStyle(pages.isEmpty ? .white.opacity(0.3) : Color.fluffyAmber)
            }
            .disabled(pages.isEmpty)
        }
    }

    private var pageCountText: String {
        if pages.isEmpty { return "Ready to scan" }
        if pages.count == 1 { return "1 page" }
        return "\(pages.count) pages"
    }

    // MARK: - Corner Brackets

    private func cornerBrackets(size: CGSize) -> some View {
        let length: CGFloat = 28
        let thickness: CGFloat = 3
        let inset: CGFloat = 6
        let color = Color.fluffyAmber

        return ZStack {
            // Top-left
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 1).fill(color)
                        .frame(width: length, height: thickness)
                    Spacer()
                }
                RoundedRectangle(cornerRadius: 1).fill(color)
                    .frame(width: thickness, height: length - thickness)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
            }
            .padding(inset)

            // Top-right
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Spacer()
                    RoundedRectangle(cornerRadius: 1).fill(color)
                        .frame(width: length, height: thickness)
                }
                RoundedRectangle(cornerRadius: 1).fill(color)
                    .frame(width: thickness, height: length - thickness)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Spacer()
            }
            .padding(inset)

            // Bottom-left
            VStack(spacing: 0) {
                Spacer()
                RoundedRectangle(cornerRadius: 1).fill(color)
                    .frame(width: thickness, height: length - thickness)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 1).fill(color)
                        .frame(width: length, height: thickness)
                    Spacer()
                }
            }
            .padding(inset)

            // Bottom-right
            VStack(spacing: 0) {
                Spacer()
                RoundedRectangle(cornerRadius: 1).fill(color)
                    .frame(width: thickness, height: length - thickness)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                HStack(spacing: 0) {
                    Spacer()
                    RoundedRectangle(cornerRadius: 1).fill(color)
                        .frame(width: length, height: thickness)
                }
            }
            .padding(inset)
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Scan Line Animation

    private func startScanLineAnimation() {
        // Animate the scan line from top to bottom of the viewfinder,
        // repeating forever. The actual height depends on the viewfinder
        // size, so we use a reasonable range and let the offset work.
        let halfHeight: CGFloat = 180
        scanLineOffset = -halfHeight
        withAnimation(
            .easeInOut(duration: 2.5)
            .repeatForever(autoreverses: true)
        ) {
            scanLineOffset = halfHeight
        }
    }

    // MARK: - Thumbnail Strip

    private var thumbnailStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, image in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                            .overlay(alignment: .bottomLeading) {
                                Text("\(index + 1)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(3)
                                    .background(Circle().fill(Color.fluffyAmber))
                                    .padding(3)
                            }

                        Button {
                            let i = index
                            withAnimation { _ = pages.remove(at: i) }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .red)
                        }
                        .offset(x: 4, y: -4)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 80)
    }

    // MARK: - Shutter Area

    private var shutterArea: some View {
        HStack {
            Spacer()

            // Shutter button
            Button {
                if pages.count < maxPages {
                    camera.capture()
                }
            } label: {
                ZStack {
                    // Outer ring
                    Circle()
                        .stroke(Color.fluffyAmber, lineWidth: 4)
                        .frame(width: 72, height: 72)
                    // Inner fill
                    Circle()
                        .fill(.white)
                        .frame(width: 60, height: 60)
                }
            }
            .disabled(pages.count >= maxPages)
            .opacity(pages.count >= maxPages ? 0.4 : 1)

            Spacer()
        }
    }

    // MARK: - Permission

    private func checkPermissionAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            camera.configure()
            camera.start()
        case .notDetermined:
            Task {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                if granted {
                    camera.configure()
                    camera.start()
                } else {
                    showingPermissionDenied = true
                }
            }
        case .denied, .restricted:
            showingPermissionDenied = true
        @unknown default:
            showingPermissionDenied = true
        }
    }
}

// MARK: - Camera Capture Manager

/// Manages AVCaptureSession for the live preview and photo capture.
/// Uses a PassthroughSubject instead of @Published so every capture
/// is guaranteed to notify the view (no SwiftUI Equatable coalescing).
private class CameraCaptureManager: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var isConfigured = false
    private var isRunning = false

    /// Fires once per captured image. Subscribe with .onReceive —
    /// more reliable than .onChange for one-shot external events.
    let capturedImage = PassthroughSubject<UIImage, Never>()

    func configure() {
        guard !isConfigured else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: .back
        ), let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            return
        }

        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        session.commitConfiguration()
        isConfigured = true
    }

    func start() {
        guard isConfigured else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
            DispatchQueue.main.async { self?.isRunning = true }
        }
    }

    func stop() {
        isRunning = false
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
    }

    func capture() {
        // Guard: session must be running or the photo output silently drops the request
        guard isRunning, session.isRunning else { return }
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraCaptureManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            print("RecipeScanView: photo capture error — \(error.localizedDescription)")
            return
        }
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            print("RecipeScanView: photo capture returned nil data")
            return
        }
        DispatchQueue.main.async { self.capturedImage.send(image) }
    }
}

// MARK: - Camera Preview UIViewRepresentable

/// Wraps AVCaptureVideoPreviewLayer in a UIView for SwiftUI.
private struct CameraPreviewRepresentable: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {}
}

/// UIView whose backing layer is an AVCaptureVideoPreviewLayer,
/// so the preview always fills the view's bounds automatically.
private class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
