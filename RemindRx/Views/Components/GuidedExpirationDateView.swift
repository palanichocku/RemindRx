//
//  GuidedExpiratioDateView.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/15/25.
//
import SwiftUI
import Vision
import VisionKit
import UIKit

// Main view for guided expiration date selection
struct GuidedExpirationDateView: View {
    // Binding to return selected date back to caller
    @Binding var selectedDate: Date?
    @Environment(\.presentationMode) var presentationMode
    
    // View state
    @State private var capturedImage: UIImage?
    @State private var ocrState: OCRState = .initial
    @State private var detectedTextBoxes: [TextBox] = []
    @State private var processingProgress: Double = 0
    @State private var errorMessage: String?
    
    // Structure to hold detected text and its location
    struct TextBox: Identifiable {
        let id = UUID()
        let text: String
        let rect: CGRect
        var possibleDate: Date?
    }
    
    // OCR processing states
    enum OCRState {
        case initial
        case capturing
        case processing
        case selecting
        case complete
        case error
    }
    
    var body: some View {
        VStack {
            // Header
            Text("Expiration Date Finder")
                .font(.headline)
                .padding(.top)
            
            // Main content based on state
            Group {
                switch ocrState {
                case .initial:
                    initialView
                case .capturing:
                    capturingView
                case .processing:
                    processingView
                case .selecting:
                    selectingView
                case .complete:
                    completeView
                case .error:
                    errorView
                }
            }
            
            // Bottom buttons
            if ocrState != .initial && ocrState != .capturing && ocrState != .processing {
                Button(action: {
                    // Cancel and dismiss
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Cancel")
                        .foregroundColor(.red)
                        .padding()
                }
            }
        }
        .padding()
        .onAppear {
            // Start the capture process immediately
            startCapture()
        }
    }
    
    // View shown before starting
    private var initialView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Prepare to scan the expiration date")
                .multilineTextAlignment(.center)
            
            Button(action: startCapture) {
                Text("Start Scanning")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
    }
    
    // View shown during document scanning
    private var capturingView: some View {
        VStack {
            Text("Scanning document...")
                .font(.headline)
            
            ProgressView()
                .padding()
        }
    }
    
    // View shown during OCR processing
    private var processingView: some View {
        VStack(spacing: 15) {
            Text("Processing image...")
                .font(.headline)
            
            ProgressView(value: processingProgress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(width: 200)
            
            Text("\(Int(processingProgress * 100))%")
                .font(.caption)
        }
    }
    
    // View for selecting the expiration date from detected text
    private var selectingView: some View {
        VStack(spacing: 15) {
            Text("Tap on the expiration date below")
                .font(.headline)
            
            Text("Look for dates following 'EXP', 'Expiry', etc.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 10)
            
            if let image = capturedImage {
                // Display the captured image with overlaid text boxes
                ScrollView {
                    ZStack {
                        // Image
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(8)
                        
                        // Overlay detected text regions
                        ForEach(detectedTextBoxes) { box in
                            ZStack {
                                // Rectangle around text
                                Rectangle()
                                    .stroke(box.possibleDate != nil ? Color.green : Color.blue, lineWidth: 2)
                                    .background(Color.blue.opacity(0.1))
                                    .frame(width: box.rect.width, height: box.rect.height)
                                    .position(x: box.rect.midX, y: box.rect.midY)
                                
                                // If it's a potential date, highlight differently
                                if box.possibleDate != nil {
                                    Rectangle()
                                        .stroke(Color.green, lineWidth: 3)
                                        .background(Color.green.opacity(0.15))
                                        .frame(width: box.rect.width, height: box.rect.height)
                                        .position(x: box.rect.midX, y: box.rect.midY)
                                }
                            }
                            .onTapGesture {
                                handleTextBoxSelection(box)
                            }
                        }
                    }
                    .padding(.vertical)
                    
                    // List of detected text for easier selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Detected Text:")
                            .font(.headline)
                            .padding(.leading)
                        
                        Divider()
                        
                        ForEach(detectedTextBoxes) { box in
                            HStack {
                                Text(box.text)
                                    .padding(.horizontal)
                                
                                Spacer()
                                
                                // Show date indicator if available
                                if let date = box.possibleDate {
                                    Text(formatDate(date))
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(5)
                            .onTapGesture {
                                handleTextBoxSelection(box)
                            }
                        }
                    }
                    .padding()
                }
            } else {
                Text("No image captured")
                    .foregroundColor(.red)
                
                Button(action: startCapture) {
                    Text("Try Again")
                        .foregroundColor(.blue)
                }
            }
            
            // Button to rescan if needed
            Button(action: startCapture) {
                Text("Scan Again")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.top)
        }
    }
    
    // View shown when expiration date has been selected
    private var completeView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Expiration Date Selected")
                .font(.headline)
            
            if let date = selectedDate {
                Text(formatDate(date))
                    .font(.title2)
                    .padding()
            }
            
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Done")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(10)
            }
        }
    }
    
    // View shown on error
    private var errorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Scanning Error")
                .font(.headline)
            
            if let message = errorMessage {
                Text(message)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            
            Button(action: startCapture) {
                Text("Try Again")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
    }
    
    // MARK: - Functions
    
    // Start the document scanning process
    func startCapture() {
        ocrState = .capturing
        
        // Create a delegate adapter
        let delegate = DocumentCameraDelegateAdapter(
            onScan: { scan in
                if scan.pageCount > 0 {
                    self.capturedImage = scan.imageOfPage(at: 0)
                    self.processImage(scan.imageOfPage(at: 0))
                } else {
                    self.errorMessage = "No pages scanned"
                    self.ocrState = .error
                }
            },
            onCancel: {
                self.presentationMode.wrappedValue.dismiss()
            },
            onError: { error in
                self.errorMessage = "Scanning error: \(error.localizedDescription)"
                self.ocrState = .error
            }
        )
        
        // Get the UIViewController that's currently presenting this SwiftUI view
        if let rootVC = UIApplication.shared.windows.first?.rootViewController {
            let presentingVC = rootVC.presentedViewController ?? rootVC
            ViewControllerPresenter.presentDocumentScanner(from: presentingVC, delegate: delegate)
        }
    }
    
    // Process the captured image with OCR
    private func processImage(_ image: UIImage) {
        ocrState = .processing
        processingProgress = 0.2
        
        // Perform OCR on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            guard let cgImage = image.cgImage else {
                DispatchQueue.main.async {
                    errorMessage = "Failed to process image"
                    ocrState = .error
                }
                return
            }
            
            // Create Vision request
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            // Text recognition request
            let textRequest = VNRecognizeTextRequest { request, error in
                // Update progress
                DispatchQueue.main.async { processingProgress = 0.6 }
                
                if let error = error {
                    DispatchQueue.main.async {
                        errorMessage = "Text recognition failed: \(error.localizedDescription)"
                        ocrState = .error
                    }
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    DispatchQueue.main.async {
                        errorMessage = "No text detected"
                        ocrState = .error
                    }
                    return
                }
                
                // Process text observations
                var textBoxes: [TextBox] = []
                
                // For each text observation
                for observation in observations {
                    // Get the top candidate with its confidence
                    if let candidate = observation.topCandidates(1).first {
                        let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // Skip very short texts
                        if text.count < 2 {
                            continue
                        }
                        
                        // Get bounding box in normalized coordinates (0-1)
                        var rect = observation.boundingBox
                        
                        // Convert to image coordinates
                        rect.origin.y = 1 - rect.origin.y - rect.height
                        
                        // Scale to image size
                        let imageSize = image.size
                        let scaledRect = CGRect(
                            x: rect.origin.x * imageSize.width,
                            y: rect.origin.y * imageSize.height,
                            width: rect.width * imageSize.width,
                            height: rect.height * imageSize.height
                        )
                        
                        // Check if this text might be a date
                        var possibleDate: Date? = nil
                        if let date = extractDateFromText(text) {
                            if isReasonableExpirationDate(date) {
                                possibleDate = date
                            }
                        }
                        
                        // Add to text boxes
                        let textBox = TextBox(text: text, rect: scaledRect, possibleDate: possibleDate)
                        textBoxes.append(textBox)
                    }
                }
                
                // Final update on main thread
                DispatchQueue.main.async {
                    detectedTextBoxes = textBoxes
                    processingProgress = 1.0
                    ocrState = .selecting
                }
            }
            
            // Configure the text recognition request
            textRequest.recognitionLevel = .accurate
            textRequest.usesLanguageCorrection = true
            
            // Execute the request
            do {
                try requestHandler.perform([textRequest])
            } catch {
                DispatchQueue.main.async {
                    errorMessage = "Failed to process image: \(error.localizedDescription)"
                    ocrState = .error
                }
            }
        }
    }
    
    // Handle when user selects a text box
    private func handleTextBoxSelection(_ box: TextBox) {
        // If this box already has a detected date, use it
        if let date = box.possibleDate {
            selectedDate = date
            ocrState = .complete
            return
        }
        
        // Otherwise, try to parse it as a date
        if let date = extractDateFromText(box.text) {
            if isReasonableExpirationDate(date) {
                selectedDate = date
                ocrState = .complete
            } else {
                // Show alert for unreasonable date
                errorMessage = "The selected date doesn't seem to be a valid expiration date."
                // Stay in selecting state but show an alert
            }
        } else {
            // Try to look for date patterns
            let dateExtractor = EnhancedDateExtractor()
            if let date = dateExtractor.findDate(in: box.text) {
                selectedDate = date
                ocrState = .complete
            } else {
                // No date found in this text
                errorMessage = "No valid date found in the selected text."
                // Stay in selecting state but show an alert
            }
        }
    }
    
    // Format date for display
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    // Extract date from text - use the enhanced methods
    private func extractDateFromText(_ text: String) -> Date? {
        let dateExtractor = EnhancedDateExtractor()
        return dateExtractor.findDate(in: text)
    }
    
    // Check if a date is reasonable for an expiration date
    private func isReasonableExpirationDate(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        
        // Medicines typically expire 6 months to 5 years from manufacture
        // Allow a bit of leeway in both directions
        let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: now)!
        let sixYearsFromNow = calendar.date(byAdding: .year, value: 6, to: now)!
        
        return date >= sixMonthsAgo && date <= sixYearsFromNow
    }
}

// Adapter to bridge VNDocumentCameraViewControllerDelegate to SwiftUI
class DocumentCameraDelegateAdapter: NSObject, VNDocumentCameraViewControllerDelegate {
    private let onScan: (VNDocumentCameraScan) -> Void
    private let onCancel: () -> Void
    private let onError: (Error) -> Void
    
    init(onScan: @escaping (VNDocumentCameraScan) -> Void,
         onCancel: @escaping () -> Void,
         onError: @escaping (Error) -> Void) {
        self.onScan = onScan
        self.onCancel = onCancel
        self.onError = onError
        super.init()
    }
    
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        controller.dismiss(animated: true)
        onScan(scan)
    }
    
    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true)
        onCancel()
    }
    
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        controller.dismiss(animated: true)
        onError(error)
    }
}

// Enhanced date extractor with more robust pattern matching
class EnhancedDateExtractor {
    func findDate(in text: String) -> Date? {
        // Try to extract date using various approaches
        
        // 1. Clean the text to handle OCR quirks
        let cleanedText = text.replacingOccurrences(of: "[^0-9a-zA-Z/\\-\\. ]", with: " ", options: .regularExpression)
                             .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                             .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 2. Try to extract numeric dates (MM/DD/YYYY, etc.)
        if let date = extractNumericDate(from: cleanedText) {
            return date
        }
        
        // 3. Try to extract text-based dates (Jan 2023, etc.)
        if let date = extractTextDate(from: cleanedText) {
            return date
        }
        
        return nil
    }
    
    // Extract numeric dates (MM/DD/YYYY, MM/YYYY, etc.)
    private func extractNumericDate(from text: String) -> Date? {
        // Common numeric date patterns
        let patterns = [
            #"\b\d{1,2}[/\\-\\.]\d{2,4}\b"#,                    // MM/YYYY or MM-YYYY
            #"\b\d{1,2}[/\\-\\.]\d{1,2}[/\\-\\.]\d{2,4}\b"#,    // MM/DD/YYYY or DD/MM/YYYY
            #"\b\d{4}[/\\-\\.]\d{1,2}[/\\-\\.]\d{1,2}\b"#,      // YYYY/MM/DD
            #"\b\d{4}[/\\-\\.]\d{1,2}\b"#                       // YYYY/MM
        ]
        
        // Try each pattern
        for pattern in patterns {
            if let dateString = extractPattern(pattern, from: text) {
                // Normalize the date string
                let normalized = normalizeDate(dateString)
                
                // Try common date formats
                let formats = ["MM/yyyy", "MM/dd/yyyy", "yyyy/MM/dd", "yyyy/MM", "dd/MM/yyyy"]
                for format in formats {
                    if let date = parseDate(normalized, format: format) {
                        return date
                    }
                }
                
                // Handle 2-digit years
                if let date = handleTwoDigitYear(normalized) {
                    return date
                }
            }
        }
        
        return nil
    }
    
    // Extract text-based dates (Jan 2023, etc.)
    private func extractTextDate(from text: String) -> Date? {
        // Month name patterns
        let patterns = [
            #"\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]* \d{2,4}\b"#,
            #"\b(January|February|March|April|May|June|July|August|September|October|November|December) \d{2,4}\b"#,
            #"\b\d{1,2} (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]* \d{2,4}\b"#,
            #"\b\d{1,2} (January|February|March|April|May|June|July|August|September|October|November|December) \d{2,4}\b"#
        ]
        
        // Try each pattern
        for pattern in patterns {
            if let dateString = extractPattern(pattern, from: text) {
                // Try common month formats
                let formats = ["MMM yyyy", "MMMM yyyy", "d MMM yyyy", "d MMMM yyyy"]
                for format in formats {
                    if let date = parseDate(dateString, format: format) {
                        return date
                    }
                }
            }
        }
        
        return nil
    }
    
    // Helper: Extract pattern from text
    private func extractPattern(_ pattern: String, from text: String) -> String? {
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let nsString = text as NSString
            let results = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
            if let match = results.first {
                return nsString.substring(with: match.range)
            }
        } catch {
            print("Regex error: \(error)")
        }
        return nil
    }
    
    // Helper: Normalize date string
    private func normalizeDate(_ dateString: String) -> String {
        return dateString
            .replacingOccurrences(of: "\\", with: "/")
            .replacingOccurrences(of: ".", with: "/")
            .replacingOccurrences(of: "-", with: "/")
    }
    
    // Helper: Parse date with format
    private func parseDate(_ dateString: String, format: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.isLenient = true
        return formatter.date(from: dateString)
    }
    
    // Helper: Handle 2-digit years
    private func handleTwoDigitYear(_ dateString: String) -> Date? {
        let components = dateString.components(separatedBy: "/")
        if components.count >= 2 {
            let lastComponent = components.last!
            if lastComponent.count == 2, let year = Int(lastComponent) {
                // Expand 2-digit year: 00-49 -> 2000-2049, 50-99 -> 1950-1999
                let fullYear = year < 50 ? "20\(lastComponent)" : "19\(lastComponent)"
                
                // Rebuild date string with full year
                var newComponents = components
                newComponents[components.count - 1] = fullYear
                let newDateString = newComponents.joined(separator: "/")
                
                // Try to parse with common formats
                let formats = ["MM/yyyy", "MM/dd/yyyy", "yyyy/MM/dd", "dd/MM/yyyy"]
                for format in formats {
                    if let date = parseDate(newDateString, format: format) {
                        return date
                    }
                }
            }
        }
        return nil
    }
}
