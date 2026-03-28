import AVFoundation
import SwiftUI

// MARK: - Barcode Scanner Service

/// Manages camera-based barcode scanning for pantry management.
/// Uses AVFoundation for real-time barcode detection.
@Observable
final class BarcodeScannerService: NSObject {
    var scannedCode: String?
    var isScanning = false
    var errorMessage: String?

    private var captureSession: AVCaptureSession?

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

        guard let device = AVCaptureDevice.default(for: .video),
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

        Task.detached { [session] in
            session.startRunning()
        }
    }

    func stopScanning() {
        captureSession?.stopRunning()
        captureSession = nil
        isScanning = false
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension BarcodeScannerService: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let metadata = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = metadata.stringValue else {
            return
        }

        scannedCode = code
        stopScanning()
    }
}

// MARK: - Barcode Lookup (Stub)

/// Placeholder for barcode-to-product lookup.
/// In production, this would integrate with a product database API.
enum BarcodeLookupService {

    struct ProductInfo {
        var name: String
        var brand: String?
        var category: IngredientCategory
        var barcode: String
    }

    static func lookup(barcode: String) async throws -> ProductInfo? {
        // TODO: Integrate with Open Food Facts or similar product database API
        return nil
    }
}
