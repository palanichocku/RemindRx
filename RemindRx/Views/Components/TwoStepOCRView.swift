import SwiftUI
import UIKit
import Vision
import VisionKit

// Use the already defined OCRProcessingService instead of creating a new one
// This avoids the "Cannot find EnhancedOCRProcessingService" error

struct TwoStepOCRView: View {
    var onCapture: (OCRResult) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    // State for controlling flow
    @State private var isShowingScanner = true
    @State private var isProcessing = false
    @State private var processingStep: OCRStep = .medicineDetails
    @State private var processingPhase: OCRProcessingStatusView.OCRProcessingPhase = .scanning
    @State private var processingProgress: Double = 0.0
    
    // Results of processing
    @State private var medicineResult = OCRResult()
    @State private var showResultPreview = false
    @State private var showExpiryDateScan = false
    
    // Track if user explicitly skipped expiry scan
    @State private var userSkippedExpiryScan = false
    
    enum OCRStep {
        case medicineDetails
        case expirationDate
    }
    
    var body: some View {
        ZStack {
            // Background color
            Color(.systemBackground).edgesIgnoringSafeArea(.all)
            
            if isShowingScanner {
                // Show document scanner
                TwoStepDocumentScannerView( // Renamed to avoid conflict
                    onScan: { scan in
                        // Begin processing the scan
                        isShowingScanner = false
                        isProcessing = true
                        processingPhase = .scanning
                        processDocumentScan(scan)
                    },
                    onCancel: {
                        // User canceled scanning
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            } else if isProcessing {
                // Show processing status
                OCRProcessingStatusView(
                    phase: processingPhase,
                    progress: processingProgress
                )
            } else if showResultPreview {
                // Show result preview for medicine details
                medicineResultPreview
            } else if showExpiryDateScan {
                // Optional step to scan expiration date separately
                expirationScanView
            }
        }
        .alert(isPresented: $userSkippedExpiryScan) {
            Alert(
                title: Text("Skip Expiration Date"),
                message: Text("You can set the expiration date manually in the next screen."),
                primaryButton: .default(Text("Continue")) {
                    // Complete without expiry date
                    completeOCRProcess()
                },
                secondaryButton: .cancel() {
                    // Go back to show the expiry scan option
                    showExpiryDateScan = true
                }
            )
        }
    }
    
    // MARK: - Views
    
    // Medicine details result preview
    private var medicineResultPreview: some View {
        OCRResultPreviewView(
            result: medicineResult,
            onConfirm: {
                // Continue to expiry date step if needed
                showResultPreview = false
                showExpiryDateScan = true
            },
            onEdit: {
                // Go directly to form (skip expiry date step)
                completeOCRProcess()
            },
            onCancel: {
                // Cancel OCR process
                presentationMode.wrappedValue.dismiss()
            }
        )
    }
    
    // Expiration date scan view
    private var expirationScanView: some View {
        VStack(spacing: 24) {
            Text("Scan Expiration Date")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Position your camera to focus on the expiration date. This is usually found on the bottom or side of the medicine packaging.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .padding()
            
            Text("Look for text starting with 'EXP', 'Expiry', or similar.")
                .italic()
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            HStack(spacing: 20) {
                Button(action: {
                    // Skip expiry date scan
                    userSkippedExpiryScan = true
                }) {
                    Text("Skip")
                        .frame(minWidth: 120)
                        .padding()
                        .foregroundColor(.primary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                }
                
                Button(action: {
                    // Launch dedicated expiry date scanner
                    launchExpiryDateScanner()
                }) {
                    Text("Scan Now")
                        .frame(minWidth: 120)
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
            .padding(.top, 20)
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Process methods
    
    private func processDocumentScan(_ scan: VNDocumentCameraScan) {
        switch processingStep {
        case .medicineDetails:
            processMedicineDetailsStep(scan)
        case .expirationDate:
            processExpirationDateStep(scan)
        }
    }
    
    private func processMedicineDetailsStep(_ scan: VNDocumentCameraScan) {
        // Simulate processing phases with delays for UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            processingPhase = .analyzing
            processingProgress = 0.3
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                processingPhase = .extractingText
                processingProgress = 0.6
                
                // Use the OCR processing service
                self.extractMedicineDetails(from: scan) { result in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        processingPhase = .complete
                        processingProgress = 1.0
                        medicineResult = result
                        
                        // Show the preview after a brief pause
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isProcessing = false
                            showResultPreview = true
                        }
                    }
                }
            }
        }
    }
    
    private func processExpirationDateStep(_ scan: VNDocumentCameraScan) {
        processingPhase = .findingExpirationDate
        processingProgress = 0.5
        
        // Process the image specifically for expiration date
        extractExpirationDate(from: scan) { date in
            DispatchQueue.main.async {
                processingPhase = .complete
                processingProgress = 1.0
                
                // Update the medicine result with the found date
                if let date = date {
                    medicineResult.expirationDate = date
                }
                
                // Complete the OCR process
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isProcessing = false
                    completeOCRProcess()
                }
            }
        }
    }
    
    private func extractMedicineDetails(from scan: VNDocumentCameraScan, completion: @escaping (OCRResult) -> Void) {
        // Extract images from scan
        let images = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
        
        // Process first image for medicine details
        if let firstImage = images.first {
            // Create a blank result to build upon
            var result = OCRResult()
            
            // Process the image using Vision framework
            if let cgImage = firstImage.cgImage {
                let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                
                let textRecognitionRequest = VNRecognizeTextRequest { request, error in
                    guard error == nil,
                          let observations = request.results as? [VNRecognizedTextObservation] else {
                        completion(result)
                        return
                    }
                    
                    // Extract all recognized text
                    let recognizedText = observations.compactMap { observation in
                        observation.topCandidates(1).first?.string
                    }
                    
                    // Extract information from the recognized text manually
                    result.name = self.findMedicineName(in: recognizedText) ?? ""
                    result.manufacturer = self.findManufacturer(in: recognizedText) ?? ""
                    result.description = self.findDescription(in: recognizedText) ?? ""
                    result.isPrescription = self.checkIfPrescription(in: recognizedText)
                    result.barcode = self.findBarcode(in: recognizedText)
                    
                    completion(result)
                }
                
                // Configure for accuracy
                textRecognitionRequest.recognitionLevel = VNRequestTextRecognitionLevel.accurate
                textRecognitionRequest.usesLanguageCorrection = true
                
                do {
                    try requestHandler.perform([textRecognitionRequest])
                } catch {
                    print("Error performing text recognition: \(error)")
                    completion(result)
                }
            } else {
                completion(result)
            }
        } else {
            completion(OCRResult())
        }
    }
    
    private func extractExpirationDate(from scan: VNDocumentCameraScan, completion: @escaping (Date?) -> Void) {
        // Extract images from scan
        let images = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
        
        // Process first image for expiration date
        if let firstImage = images.first {
            var expiryDate: Date? = nil
            
            if let cgImage = firstImage.cgImage {
                let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                
                let textRecognitionRequest = VNRecognizeTextRequest { request, error in
                    guard error == nil,
                          let observations = request.results as? [VNRecognizedTextObservation] else {
                        completion(nil)
                        return
                    }
                    
                    // Extract all recognized text
                    let recognizedText = observations.compactMap { observation in
                        observation.topCandidates(1).first?.string
                    }
                    
                    // Look specifically for expiration date patterns
                    let expiryKeywords = ["exp", "exp.", "exp date", "expiry", "expire", "expires", "expiration", "use by", "best by"]
                    
                    // First pass: look for explicit expiration date mentions
                    for line in recognizedText {
                        let lowercaseLine = line.lowercased()
                        
                        // Check if line contains expiration keywords
                        for keyword in expiryKeywords {
                            if lowercaseLine.contains(keyword) {
                                // Try to extract date from this line
                                if let date = extractDateFromText(line) {
                                    expiryDate = date
                                    break
                                }
                            }
                        }
                        
                        if expiryDate != nil { break }
                    }
                    
                    // Second pass: look for date patterns if we didn't find one
                    if expiryDate == nil {
                        for line in recognizedText {
                            if let date = extractDateFromText(line) {
                                // Verify it's a future date or reasonably recent
                                let calendar = Calendar.current
                                let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: Date()) ?? Date()
                                let fiveYearsFromNow = calendar.date(byAdding: .year, value: 5, to: Date()) ?? Date()
                                
                                if date >= sixMonthsAgo && date <= fiveYearsFromNow {
                                    expiryDate = date
                                    break
                                }
                            }
                        }
                    }
                    
                    completion(expiryDate)
                }
                
                // Configure for high accuracy
                textRecognitionRequest.recognitionLevel = VNRequestTextRecognitionLevel.accurate
                textRecognitionRequest.usesLanguageCorrection = true
                
                do {
                    try requestHandler.perform([textRecognitionRequest])
                } catch {
                    print("Error searching for expiration date: \(error)")
                    completion(nil)
                }
            } else {
                completion(nil)
            }
        } else {
            completion(nil)
        }
    }
    
    private func extractDateFromText(_ text: String) -> Date? {
        // Define date formatters for various common date formats
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        // Common date formats found on medicine packaging
        let dateFormats = [
            "MM/yyyy",
            "MM/dd/yyyy",
            "yyyy-MM-dd",
            "MMM yyyy",
            "MMMM yyyy",
            "dd MMM yyyy",
            "yyyy-MM",
            "MM-yyyy"
        ]
        
        // Common date patterns to extract from text
        let datePatterns = [
            #"\d{1,2}/\d{1,2}/\d{2,4}"#,     // MM/DD/YYYY or DD/MM/YYYY
            #"\d{1,2}/\d{2,4}"#,             // MM/YYYY
            #"\d{2,4}-\d{1,2}-\d{1,2}"#,     // YYYY-MM-DD
            #"\d{2,4}-\d{1,2}"#,             // YYYY-MM
            #"\d{1,2}-\d{1,2}-\d{2,4}"#,     // DD-MM-YYYY or MM-DD-YYYY
            #"\d{1,2}-\d{2,4}"#,             // MM-YYYY
            #"[A-Za-z]{3,} \d{2,4}"#,        // MMM YYYY or MMMM YYYY
            #"\d{1,2} [A-Za-z]{3,} \d{2,4}"# // DD MMM YYYY or DD MMMM YYYY
        ]
        
        for pattern in datePatterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let dateString = String(text[match])
                
                for format in dateFormats {
                    dateFormatter.dateFormat = format
                    if let date = dateFormatter.date(from: dateString) {
                        // Check if date is reasonable for expiration
                        let calendar = Calendar.current
                        let minDate = calendar.date(byAdding: .month, value: -6, to: Date()) ?? Date()
                        let maxDate = calendar.date(byAdding: .year, value: 10, to: Date()) ?? Date()
                        
                        if date >= minDate && date <= maxDate {
                            return date
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    private func launchExpiryDateScanner() {
        processingStep = .expirationDate
        isShowingScanner = true
    }
    
    private func completeOCRProcess() {
        // Return the complete result
        onCapture(medicineResult)
        presentationMode.wrappedValue.dismiss()
    }
    
    // MARK: - Text Extraction Helper Methods
    
    private func findMedicineName(in textLines: [String]) -> String? {
        // Medicine names are typically in larger font at the top of packaging
        // Look for distinctive patterns - often one of the first few lines
        
        let excludedWords = ["drug", "facts", "information", "patient", "healthcare", "professional", "storage", "uses", "warnings"]
        
        for line in textLines.prefix(5) {
            let cleanLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip short lines, empty lines or lines with too many numbers
            if cleanLine.count < 3 || cleanLine.isEmpty || cleanLine.count > 50 {
                continue
            }
            
            // Skip lines that are likely not the medicine name
            let lowercaseLine = cleanLine.lowercased()
            if excludedWords.contains(where: { lowercaseLine.contains($0) }) {
                continue
            }
            
            // Check if line contains too many digits (probably not a name)
            let digitCount = lowercaseLine.filter { $0.isNumber }.count
            if Double(digitCount) / Double(lowercaseLine.count) > 0.2 {
                continue
            }
            
            // If we've filtered this far, this is likely a good candidate
            return cleanLine
        }
        
        // Fallback - return the first non-empty line that's a reasonable length
        for line in textLines.prefix(10) {
            let cleanLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanLine.count >= 3 && cleanLine.count < 50 {
                return cleanLine
            }
        }
        
        return nil
    }
    
    private func findManufacturer(in textLines: [String]) -> String? {
        // Keywords that often precede manufacturer information
        let manufacturerKeywords = ["manufactured by", "distributed by", "marketed by", "by:", "manufactured for"]
        
        for line in textLines {
            let lowercaseLine = line.lowercased()
            
            for keyword in manufacturerKeywords {
                if lowercaseLine.contains(keyword) {
                    // Extract the part after the keyword
                    if let range = lowercaseLine.range(of: keyword) {
                        let manufacturerPart = String(line[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !manufacturerPart.isEmpty {
                            return manufacturerPart
                        }
                    }
                }
            }
        }
        
        // If no clear manufacturer found, look for lines that might be company names
        let companyIndicators = ["inc.", "llc", "ltd", "corp.", "corporation", "pharmaceuticals", "pharma"]
        
        for line in textLines {
            let lowercaseLine = line.lowercased()
            
            if companyIndicators.contains(where: { lowercaseLine.contains($0) }) &&
               !lowercaseLine.contains("www.") &&
               !lowercaseLine.contains("http") {
                // This line likely contains a company name (but skip website URLs)
                return line.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return nil
    }
    
    private func findDescription(in textLines: [String]) -> String? {
        // Keywords that often appear in medicine descriptions
        let descriptionKeywords = ["contains", "active ingredient", "each tablet", "for the treatment of",
                                 "mg", "mcg", "ml", "treatment", "relief", "symptoms"]
        
        // Sections that might contain descriptions
        let descriptionSections = ["description", "active ingredients", "indications", "uses", "about"]
        
        // Look for description sections
        var descriptionLines: [String] = []
        var inDescriptionSection = false
        
        for line in textLines {
            let lowercaseLine = line.lowercased()
            
            // Check for section headers
            for section in descriptionSections {
                if lowercaseLine.contains(section) && (lowercaseLine.count - section.count) < 10 {
                    inDescriptionSection = true
                    break
                }
            }
            
            // End of section detection
            if inDescriptionSection {
                if lowercaseLine.contains("directions") ||
                   lowercaseLine.contains("warnings") ||
                   lowercaseLine.contains("storage") ||
                   lowercaseLine.contains("dosage") {
                    break
                }
                
                // Skip very short lines
                if line.count > 5 {
                    descriptionLines.append(line)
                }
                
                // Limit description to keep it reasonable
                if descriptionLines.count >= 3 {
                    break
                }
            }
        }
        
        // If no section found, look for lines with description keywords
        if descriptionLines.isEmpty {
            for line in textLines {
                let lowercaseLine = line.lowercased()
                
                if descriptionKeywords.contains(where: { lowercaseLine.contains($0) }) {
                    descriptionLines.append(line)
                    
                    // Limit to a reasonable size
                    if descriptionLines.count >= 2 {
                        break
                    }
                }
            }
        }
        
        // Return the compiled description
        if !descriptionLines.isEmpty {
            return descriptionLines.joined(separator: ". ").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return nil
    }
    
    private func checkIfPrescription(in textLines: [String]) -> Bool {
        // Look for keywords indicating prescription status
        let prescriptionIndicators = ["rx only", "prescription only", "prescription drug", "federal law prohibits"]
        
        for line in textLines {
            let lowercaseLine = line.lowercased()
            
            for indicator in prescriptionIndicators {
                if lowercaseLine.contains(indicator) {
                    return true
                }
            }
        }
        
        return false
    }
    
    private func findBarcode(in textLines: [String]) -> String? {
        // Common barcode formats: NDC codes, UPC, EAN, etc.
        
        // NDC code pattern (National Drug Code)
        let ndcPatterns = [
            #"NDC\s*\d{1,5}[-\s]?\d{1,4}[-\s]?\d{1,2}"#,   // NDC XXXXX-XXXX-XX format
            #"NDC\s*\d{1,5}[-\s]?\d{1,4}"#                 // NDC XXXXX-XXXX format
        ]
        
        // UPC/EAN patterns (common retail barcodes)
        let barcodePatterns = [
            #"\b\d{12}\b"#,    // UPC-A (12 digits)
            #"\b\d{13}\b"#,    // EAN-13 (13 digits)
            #"\b\d{8}\b"#      // EAN-8 (8 digits)
        ]
        
        // First try to find NDC codes
        for pattern in ndcPatterns {
            if let barcode = searchPattern(pattern: pattern, in: textLines) {
                // Clean up any spaces or hyphens
                return barcode.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            }
        }
        
        // Then try to find UPC/EAN barcodes
        for pattern in barcodePatterns {
            if let barcode = searchPattern(pattern: pattern, in: textLines) {
                return barcode
            }
        }
        
        return nil
    }
    
    private func searchPattern(pattern: String, in textLines: [String]) -> String? {
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            
            for line in textLines {
                let nsString = line as NSString
                let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsString.length))
                
                if let match = matches.first {
                    return nsString.substring(with: match.range)
                }
            }
        } catch {
            print("Regex error: \(error.localizedDescription)")
        }
        
        return nil
    }
}

/// A simple wrapper around VNDocumentCameraViewController
/// Renamed to avoid conflicts with existing DocumentScannerView
struct TwoStepDocumentScannerView: UIViewControllerRepresentable {
    var onScan: (VNDocumentCameraScan) -> Void
    var onCancel: () -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        let scannerViewController = VNDocumentCameraViewController()
        scannerViewController.delegate = context.coordinator
        return scannerViewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Nothing to update
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan, onCancel: onCancel)
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScan: (VNDocumentCameraScan) -> Void
        let onCancel: () -> Void
        
        init(onScan: @escaping (VNDocumentCameraScan) -> Void, onCancel: @escaping () -> Void) {
            self.onScan = onScan
            self.onCancel = onCancel
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            onScan(scan)
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onCancel()
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            print("Document scanner failed with error: \(error.localizedDescription)")
            onCancel()
        }
    }
}
