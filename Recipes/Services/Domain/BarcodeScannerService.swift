@preconcurrency import AVFoundation
import SwiftUI

// MARK: - Barcode Scanner Service

/// Manages camera-based barcode scanning for pantry management.
/// Uses AVFoundation for real-time barcode detection, with Open Food Facts
/// integration for automatic product identification.
@Observable
@MainActor
final class BarcodeScannerService: NSObject {
    var scannedCode: String?
    var isScanning = false
    var errorMessage: String?
    var lookupResult: OpenFoodFactsService.Product?
    var isLookingUp = false

    private(set) var captureSession: AVCaptureSession?

    /// Supported barcode types for grocery items.
    static let supportedBarcodeTypes: [AVMetadataObject.ObjectType] = [
        .ean8, .ean13, .upce, .code128, .code39, .code93, .itf14
    ]

    func requestCameraAccess() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    func startScanning() {
        guard captureSession == nil else { return }

        let session = AVCaptureSession()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            errorMessage = "Unable to access camera."
            return
        }

        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            errorMessage = "Unable to configure barcode scanning."
            return
        }

        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = Self.supportedBarcodeTypes

        captureSession = session
        isScanning = true
        scannedCode = nil
        lookupResult = nil
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
    }

    func stopScanning() {
        captureSession?.stopRunning()
        captureSession = nil
        isScanning = false
    }

    func resetForNextScan() {
        scannedCode = nil
        lookupResult = nil
        errorMessage = nil
        startScanning()
    }

    /// Look up the scanned barcode against Open Food Facts.
    func lookupScannedProduct() async {
        guard let code = scannedCode else { return }

        isLookingUp = true
        defer { isLookingUp = false }

        do {
            lookupResult = try await OpenFoodFactsService.lookup(barcode: code)
            if lookupResult == nil {
                errorMessage = "Product not found in database. You can add it manually."
            }
        } catch {
            errorMessage = "Lookup failed: \(error.localizedDescription)"
        }
    }

    /// Convert the lookup result to a PantryItem.
    func createPantryItem(quantity: Double = 1, unit: MeasurementUnit = .piece, expirationDate: Date? = nil) -> PantryItem? {
        guard let product = lookupResult else { return nil }

        return PantryItem(
            name: product.name,
            category: product.category,
            barcode: product.barcode,
            quantity: quantity,
            unit: unit,
            expirationDate: expirationDate
        )
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension BarcodeScannerService: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let metadata = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = metadata.stringValue else {
            return
        }

        // Safe: delegate queue is explicitly set to .main (line 58)
        MainActor.assumeIsolated {
            scannedCode = code
            stopScanning()
            Task { await lookupScannedProduct() }
        }
    }
}

// MARK: - Camera Preview (UIViewRepresentable)

/// SwiftUI wrapper around AVCaptureVideoPreviewLayer for live camera preview.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.previewLayer.session = session
    }
}

final class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}
