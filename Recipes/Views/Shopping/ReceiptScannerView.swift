import SwiftUI
import SwiftData
import VisionKit
import Vision

// MARK: - Receipt Parser Service

enum ReceiptParserService {

    struct ParsedReceipt {
        var storeName: String?
        var items: [(name: String, price: Double)]
        var total: Double?
    }

    /// Parses raw OCR text from a receipt into structured data.
    static func parseReceiptText(_ text: String) -> ParsedReceipt {
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }

        var storeName: String?
        var items: [(name: String, price: Double)] = []
        var total: Double?

        // The first non-empty line is typically the store name.
        storeName = lines.first(where: { !$0.isEmpty })

        let pricePattern = /\$?\s*(\d+\.\d{2})/
        let totalPattern = /(?i)(total|amount\s*due|balance\s*due|grand\s*total)/

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Check if this line contains a total indicator.
            if trimmed.contains(totalPattern) {
                if let match = trimmed.firstMatch(of: pricePattern) {
                    total = Double(match.1)
                }
                continue
            }

            // Skip lines that look like subtax, tax, change, etc.
            let skipPattern = /(?i)(subtotal|sub\s*total|tax|change|cash|credit|debit|visa|mastercard|card)/
            if trimmed.contains(skipPattern) {
                continue
            }

            // Try to extract an item name paired with a price.
            if let match = trimmed.firstMatch(of: pricePattern) {
                let priceRange = match.range
                let nameEndIndex = priceRange.lowerBound
                var itemName = String(trimmed[trimmed.startIndex..<nameEndIndex])
                    .trimmingCharacters(in: .whitespaces.union(.punctuationCharacters))

                // Remove leading dollar signs or quantity prefixes like "2x".
                let qtyPrefix = /^\d+\s*[xX]\s*/
                itemName = itemName.replacing(qtyPrefix, with: "")

                if let price = Double(match.1), !itemName.isEmpty {
                    items.append((name: itemName, price: price))
                }
            }
        }

        return ParsedReceipt(storeName: storeName, items: items, total: total)
    }
}

// MARK: - Data Scanner Representable

struct ReceiptScannerRepresentable: UIViewControllerRepresentable {
    @Binding var scannedText: String
    @Binding var isScanning: Bool
    let onScanComplete: () -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        if isScanning {
            try? uiViewController.startScanning()
        } else {
            uiViewController.stopScanning()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let parent: ReceiptScannerRepresentable

        init(parent: ReceiptScannerRepresentable) {
            self.parent = parent
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            processItems(allItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            processItems(allItems)
        }

        private func processItems(_ items: [RecognizedItem]) {
            let lines: [String] = items.compactMap { item in
                switch item {
                case .text(let text):
                    return text.transcript
                default:
                    return nil
                }
            }
            parent.scannedText = lines.joined(separator: "\n")
        }
    }
}

// MARK: - Receipt Scanner View

struct ReceiptScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var scannedText = ""
    @State private var isScanning = true
    @State private var parsedReceipt: ReceiptParserService.ParsedReceipt?
    @State private var editedStoreName = ""
    @State private var editedTotal = ""
    @State private var editedItems: [(name: String, price: String)] = []
    @State private var showingReview = false
    @State private var recognizedImage: UIImage?
    @State private var isProcessing = false
    @State private var errorMessage: String?

    private var isScannerAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if showingReview {
                    reviewView
                } else {
                    scannerView
                }
            }
            .navigationTitle("Scan Receipt")
            .toolbarBackground(.glass, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Scanner Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Scanner View

    @ViewBuilder
    private var scannerView: some View {
        if isScannerAvailable {
            ZStack(alignment: .bottom) {
                ReceiptScannerRepresentable(
                    scannedText: $scannedText,
                    isScanning: $isScanning,
                    onScanComplete: processScannedText
                )
                .ignoresSafeArea()

                VStack(spacing: 16) {
                    if !scannedText.isEmpty {
                        Text("\(scannedText.components(separatedBy: .newlines).count) lines detected")
                            .font(.caption)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .glassEffect(.regular, in: .capsule)
                    }

                    HStack(spacing: 20) {
                        Button {
                            processScannedText()
                        } label: {
                            Label("Scan", systemImage: "doc.text.viewfinder")
                                .font(.headline)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.glass)
                        .disabled(scannedText.isEmpty || isProcessing)

                        Button {
                            captureWithVisionOCR()
                        } label: {
                            Label("Photo OCR", systemImage: "camera.fill")
                                .font(.headline)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.glass)
                        .disabled(isProcessing)
                    }
                    .padding(.bottom, 30)
                }
            }
            .overlay {
                if isProcessing {
                    ProgressView("Processing receipt...")
                        .padding(24)
                        .glassEffect(.regular, in: .rect(cornerRadius: 16))
                }
            }
        } else {
            ContentUnavailableView(
                "Scanner Unavailable",
                systemImage: "camera.fill",
                description: Text("This device does not support document scanning. Ensure the camera is available and text recognition is supported.")
            )
        }
    }

    // MARK: - Review View

    private var reviewView: some View {
        Form {
            Section {
                HStack {
                    Text("Store Name")
                    Spacer()
                    TextField("Store Name", text: $editedStoreName)
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text("Store")
            }
            .listRowBackground(
                Color.clear.glassEffect(.regular, in: .rect)
            )

            Section {
                ForEach(editedItems.indices, id: \.self) { index in
                    HStack {
                        TextField("Item", text: $editedItems[index].name)
                        Spacer()
                        TextField("Price", text: $editedItems[index].price)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
                .onDelete { offsets in
                    editedItems.remove(atOffsets: offsets)
                }

                Button {
                    editedItems.append((name: "", price: "0.00"))
                } label: {
                    Label("Add Item", systemImage: "plus.circle")
                }
                .buttonStyle(.glass)
            } header: {
                Text("Items (\(editedItems.count))")
            }
            .listRowBackground(
                Color.clear.glassEffect(.regular, in: .rect)
            )

            Section {
                HStack {
                    Text("Total")
                        .fontWeight(.semibold)
                    Spacer()
                    TextField("$0.00", text: $editedTotal)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                        .fontWeight(.semibold)
                }
            }
            .listRowBackground(
                Color.clear.glassEffect(.regular, in: .rect)
            )

            Section {
                Button {
                    saveReceipt()
                } label: {
                    HStack {
                        Spacer()
                        Label("Save Receipt", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.glass)

                Button {
                    showingReview = false
                    isScanning = true
                } label: {
                    HStack {
                        Spacer()
                        Label("Re-scan", systemImage: "arrow.counterclockwise")
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.glass)
            }
            .listRowBackground(Color.clear)
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: - Processing

    private func processScannedText() {
        isScanning = false
        isProcessing = true

        let parsed = ReceiptParserService.parseReceiptText(scannedText)
        applyParsedResult(parsed)

        isProcessing = false
        showingReview = true
    }

    private func captureWithVisionOCR() {
        isProcessing = true
        isScanning = false

        // Use Vision framework OCR on the scanned text already collected
        // from the DataScanner as a fallback; in production this would
        // operate on a captured CGImage from the camera feed.
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.errorMessage = error?.localizedDescription ?? "OCR failed."
                    self.isScanning = true
                }
                return
            }

            let recognizedStrings = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }

            DispatchQueue.main.async {
                let fullText = recognizedStrings.joined(separator: "\n")
                if !fullText.isEmpty {
                    self.scannedText = fullText
                }
                let parsed = ReceiptParserService.parseReceiptText(self.scannedText)
                self.applyParsedResult(parsed)
                self.isProcessing = false
                self.showingReview = true
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        // If we already have scanned text, just parse it directly.
        if !scannedText.isEmpty {
            let parsed = ReceiptParserService.parseReceiptText(scannedText)
            applyParsedResult(parsed)
            isProcessing = false
            showingReview = true
        } else {
            isProcessing = false
            errorMessage = "No text detected. Please position the receipt in the camera view."
            isScanning = true
        }
    }

    private func applyParsedResult(_ parsed: ReceiptParserService.ParsedReceipt) {
        parsedReceipt = parsed
        editedStoreName = parsed.storeName ?? ""
        editedTotal = parsed.total.map { String(format: "%.2f", $0) } ?? ""
        editedItems = parsed.items.map { (name: $0.name, price: String(format: "%.2f", $0.price)) }
    }

    // MARK: - Save

    private func saveReceipt() {
        let receipt = GroceryReceipt(
            storeName: editedStoreName.isEmpty ? nil : editedStoreName,
            date: .now,
            totalAmount: Double(editedTotal) ?? 0
        )

        receipt.items = editedItems.compactMap { item in
            guard !item.name.isEmpty, let price = Double(item.price) else { return nil }
            return ReceiptLineItem(name: item.name, price: price, quantity: 1)
        }

        modelContext.insert(receipt)
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    ReceiptScannerView()
        .modelContainer(for: GroceryReceipt.self, inMemory: true)
}
