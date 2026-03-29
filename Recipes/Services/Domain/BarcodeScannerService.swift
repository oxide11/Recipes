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
    var capturedImage: UIImage?
    var isLLMIdentifying = false

    private(set) var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?

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

        // Add photo output for LLM-assisted identification
        let photo = AVCapturePhotoOutput()
        if session.canAddOutput(photo) {
            session.addOutput(photo)
            photoOutput = photo
        }

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
                errorMessage = "Product not found in database. Try AI identification or add manually."
            }
        } catch {
            errorMessage = "Lookup failed: \(error.localizedDescription)"
        }
    }

    /// Capture a still photo from the current session for LLM identification.
    func capturePhoto() {
        guard let photoOutput, let _ = captureSession else {
            errorMessage = "Camera not available for photo capture."
            return
        }
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    /// Use an LLM to identify a product from the barcode and/or captured photo.
    func llmIdentifyProduct(using aiRouter: AIServiceRouter) async {
        isLLMIdentifying = true
        defer { isLLMIdentifying = false }

        guard let image = capturedImage,
              let imageData = image.jpegData(compressionQuality: 0.7) else {
            // Try text-only identification with barcode
            guard let code = scannedCode else {
                errorMessage = "No barcode or photo available for AI identification."
                return
            }
            do {
                let prompt = """
                I scanned a grocery product with barcode: \(code).
                What product is this? Respond with ONLY a JSON object:
                {"name": "Product Name", "brand": "Brand or null", "category": "one of: protein, dairy, vegetable, fruit, grain, spice, herb, condiment, oil, liquid, sweetener, nut, other"}
                """
                let response = try await aiRouter.generateText(prompt: prompt, taskType: .classification)
                parseProductResponse(response, barcode: code)
            } catch {
                errorMessage = "AI identification failed: \(error.localizedDescription)"
            }
            return
        }

        let base64 = imageData.base64EncodedString()
        let barcode = scannedCode ?? "unknown"

        do {
            let prompt = """
            This is a photo of a grocery product. The barcode is: \(barcode).
            Identify this product. Respond with ONLY a JSON object:
            {"name": "Product Name", "brand": "Brand or null", "category": "one of: protein, dairy, vegetable, fruit, grain, spice, herb, condiment, oil, liquid, sweetener, nut, other"}
            """
            let response = try await aiRouter.analyzeImage(imageBase64: base64, prompt: prompt)
            parseProductResponse(response, barcode: barcode)
        } catch {
            errorMessage = "AI identification failed: \(error.localizedDescription)"
        }
    }

    private func parseProductResponse(_ response: String, barcode: String) {
        // Extract JSON from response
        guard let jsonStart = response.firstIndex(of: "{"),
              let jsonEnd = response.lastIndex(of: "}") else {
            errorMessage = "Could not parse AI response."
            return
        }
        let jsonString = String(response[jsonStart...jsonEnd])
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = json["name"] as? String else {
            errorMessage = "Could not parse AI response."
            return
        }

        let brand = json["brand"] as? String
        let categoryStr = json["category"] as? String ?? "other"
        let category = IngredientCategory(rawValue: categoryStr) ?? .other

        lookupResult = OpenFoodFactsService.Product(
            name: name,
            brand: brand,
            category: category,
            barcode: barcode
        )
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

// MARK: - AVCapturePhotoCaptureDelegate

extension BarcodeScannerService: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        MainActor.assumeIsolated {
            if let error {
                errorMessage = "Photo capture failed: \(error.localizedDescription)"
                return
            }
            guard let data = photo.fileDataRepresentation(),
                  let image = UIImage(data: data) else {
                errorMessage = "Could not process captured photo."
                return
            }
            capturedImage = image
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
