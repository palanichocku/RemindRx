//
//  DirectTwoStepOCRView.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/17/25.
//

import SwiftUI
import VisionKit
import Vision

// A very simplified, step-by-step scanner with direct control flow
struct DirectTwoStepOCRView: View {
    var onCapture: (OCRResult) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    // Steps in the flow - explicitly named for clarity
    enum Step {
        case welcome
        case scanMedicine
        case medicineScanComplete
        case processingMedicine
        case reviewMedicineResult
        case scanExpiry
        case expiryScanComplete
        case processingExpiry
        case complete
    }
    
    // Current step in the flow
    @State private var currentStep = Step.welcome
    
    // Result data
    @State private var medicineResult = OCRResult()
    @State private var medicineScan: VNDocumentCameraScan? = nil
    @State private var expiryScan: VNDocumentCameraScan? = nil
    
    // UI State
    @State private var isShowingScanner = false
    @State private var processingProgress = 0.0
    @State private var errorMessage: String? = nil
    
    var body: some View {
        VStack {
            // Step-specific content
            Group {
                switch currentStep {
                case .welcome:
                    welcomeView
                case .scanMedicine, .scanExpiry:
                    scanningView
                case .medicineScanComplete, .expiryScanComplete:
                    scanCompleteView
                case .processingMedicine, .processingExpiry:
                    processingView
                case .reviewMedicineResult:
                    reviewMedicineView
                case .complete:
                    completeView
                }
            }
            
            // Error message if needed
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
            
            // Cancel button always available except during active scanning
            if ![Step.scanMedicine, Step.scanExpiry].contains(currentStep) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.red)
                .padding()
            }
        }
        .onChange(of: currentStep) { newStep in
            // Handle step transitions
            switch newStep {
            case .scanMedicine, .scanExpiry:
                presentDocumentScanner()
            case .medicineScanComplete:
                guard let scan = medicineScan else {
                    errorMessage = "Scan failed"
                    currentStep = .welcome
                    return
                }
                currentStep = .processingMedicine
                processMedicineScan(scan)
            case .expiryScanComplete:
                guard let scan = expiryScan else {
                    errorMessage = "Scan failed"
                    currentStep = .reviewMedicineResult
                    return
                }
                currentStep = .processingExpiry
                processExpiryScan(scan)
            case .complete:
                // Return result and dismiss
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onCapture(medicineResult)
                    presentationMode.wrappedValue.dismiss()
                }
            default:
                break
            }
        }
    }
    
    // MARK: - Views
    
    private var welcomeView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.viewfinder")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Scan Medicine")
                .font(.title2)
                .bold()
            
            Text("We'll guide you through scanning your medicine in two steps:")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .top, spacing: 15) {
                    Text("1")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.blue))
                    
                    VStack(alignment: .leading) {
                        Text("Scan Medicine Package")
                            .font(.headline)
                        Text("Capture the front of the package with product name and details")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(alignment: .top, spacing: 15) {
                    Text("2")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.blue))
                    
                    VStack(alignment: .leading) {
                        Text("Scan Expiration Date")
                            .font(.headline)
                        Text("Capture the part of the package with the expiration date")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Button {
                currentStep = .scanMedicine
            } label: {
                Text("Start Scanning")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
        }
        .padding()
    }
    
    private var scanningView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text(currentStep == .scanMedicine ? "Scanning Medicine..." : "Scanning Expiration Date...")
                .font(.headline)
        }
        .padding()
    }
    
    private var scanCompleteView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Scan Complete")
                .font(.headline)
            
            ProgressView()
                .padding()
            
            Text("Processing image...")
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private var processingView: some View {
        VStack(spacing: 20) {
            Image(systemName: "gear")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .rotationEffect(.degrees(processingProgress * 360))
                .animation(Animation.linear(duration: 2).repeatForever(autoreverses: false))
            
            Text(currentStep == .processingMedicine ? "Processing Medicine Details..." : "Processing Expiration Date...")
                .font(.headline)
            
            ProgressView(value: processingProgress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(width: 200)
                .padding()
            
            Text("\(Int(processingProgress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private var reviewMedicineView: some View {
        VStack(spacing: 20) {
            Text("Medicine Details")
                .font(.title2)
                .bold()
            
            VStack(alignment: .leading, spacing: 10) {
                infoRow("Name:", medicineResult.name.isEmpty ? "Not detected" : medicineResult.name)
                
                if !medicineResult.manufacturer.isEmpty {
                    infoRow("Manufacturer:", medicineResult.manufacturer)
                }
                
                if !medicineResult.description.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Description:").bold()
                        Text(medicineResult.description)
                    }
                    .padding(.vertical, 4)
                }
                
                infoRow("Type:", medicineResult.isPrescription ? "Prescription" : "OTC")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Text("Next, let's scan the expiration date")
                .padding()
            
            Button {
                currentStep = .scanExpiry
            } label: {
                Text("Scan Expiration Date")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 40)
            
            Button {
                // Skip expiry date scanning
                currentStep = .complete
            } label: {
                Text("Skip (Set Date Manually Later)")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .padding()
    }
    
    private var completeView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Scan Complete!")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Medicine: \(medicineResult.name)")
                
                if let expiryDate = medicineResult.expirationDate {
                    Text("Expiration: \(formatDate(expiryDate))")
                } else {
                    Text("No expiration date detected")
                        .foregroundColor(.orange)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Text("Returning to medicine form...")
                .foregroundColor(.secondary)
                .padding()
            
            ProgressView()
        }
        .padding()
    }
    
    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .bold()
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .foregroundColor(value.contains("Not") ? .red : .primary)
        }
    }
    
    // MARK: - Scanner Logic
    
    private func presentDocumentScanner() {
        // Create the VNDocumentCameraViewController
        let scannerVC = VNDocumentCameraViewController()
        let delegate = DirectScannerDelegate(
            onScanComplete: { scan in
                // Handle scan completion
                if self.currentStep == .scanMedicine {
                    self.medicineScan = scan
                    // Must update state on main thread
                    DispatchQueue.main.async {
                        self.currentStep = .medicineScanComplete
                    }
                } else if self.currentStep == .scanExpiry {
                    self.expiryScan = scan
                    // Must update state on main thread
                    DispatchQueue.main.async {
                        self.currentStep = .expiryScanComplete
                    }
                }
            },
            onCancel: {
                // Handle cancellation
                DispatchQueue.main.async {
                    if self.currentStep == .scanMedicine {
                        self.currentStep = .welcome
                    } else if self.currentStep == .scanExpiry {
                        self.currentStep = .reviewMedicineResult
                    }
                }
            }
        )
        
        // Store the delegate to prevent deallocation
        _scannerDelegate = delegate
        
        // Set the delegate
        scannerVC.delegate = delegate
        
        // Find the root view controller
        if let rootVC = UIApplication.shared.windows.first?.rootViewController {
            // Find the currently presented view controller
            let presentingVC = rootVC.presentedViewController ?? rootVC
            
            // Present the scanner
            DispatchQueue.main.async {
                presentingVC.present(scannerVC, animated: true)
            }
        }
    }
    
    // Keep a reference to prevent deallocation
    @State private var _scannerDelegate: DirectScannerDelegate?
    
    private func processMedicineScan(_ scan: VNDocumentCameraScan) {
        // Start processing
        processingProgress = 0.1
        
        // Process on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            // Use OCR service to process
            let ocrService = OCRProcessingService.shared
            
            // Get all images
            let images = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            
            // Process each image
            var resultBuilder = OCRResult()
            
            for (index, image) in images.enumerated() {
                // Update progress
                DispatchQueue.main.async {
                    self.processingProgress = 0.1 + 0.8 * Double(index) / Double(images.count)
                }
                
                // Create a semaphore for synchronous processing
                let semaphore = DispatchSemaphore(value: 0)
                
                // Process the image
                ocrService.processImage(image) { result in
                    // Merge results
                    if resultBuilder.name.isEmpty && !result.name.isEmpty {
                        resultBuilder.name = result.name
                    }
                    
                    if resultBuilder.manufacturer.isEmpty && !result.manufacturer.isEmpty {
                        resultBuilder.manufacturer = result.manufacturer
                    }
                    
                    if !result.description.isEmpty {
                        if resultBuilder.description.isEmpty {
                            resultBuilder.description = result.description
                        } else {
                            resultBuilder.description += ". " + result.description
                        }
                    }
                    
                    if result.isPrescription {
                        resultBuilder.isPrescription = true
                    }
                    
                    if resultBuilder.barcode == nil && result.barcode != nil {
                        resultBuilder.barcode = result.barcode
                    }
                    
                    if resultBuilder.expirationDate == nil && result.expirationDate != nil {
                        resultBuilder.expirationDate = result.expirationDate
                    }
                    
                    semaphore.signal()
                }
                
                // Wait for processing to complete
                semaphore.wait()
            }
            
            // Final result
            DispatchQueue.main.async {
                self.processingProgress = 1.0
                self.medicineResult = resultBuilder
                
                // Move to next step
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.currentStep = .reviewMedicineResult
                }
            }
        }
    }
    
    private func processExpiryScan(_ scan: VNDocumentCameraScan) {
        // Start processing
        processingProgress = 0.1
        
        // Process on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            // Get all images
            let images = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            
            // Process each image for expiry date
            var bestDate: Date? = nil
            let dateExtractor = EnhancedDateExtractor()
            
            for (index, image) in images.enumerated() {
                // Update progress
                DispatchQueue.main.async {
                    self.processingProgress = 0.1 + 0.8 * Double(index) / Double(images.count)
                }
                
                // Extract text from image
                if let cgImage = image.cgImage {
                    let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                    
                    // Create a semaphore for synchronous processing
                    let semaphore = DispatchSemaphore(value: 0)
                    
                    // Create text recognition request
                    let textRequest = VNRecognizeTextRequest { request, error in
                        guard let observations = request.results as? [VNRecognizedTextObservation] else {
                            semaphore.signal()
                            return
                        }
                        
                        // Extract text
                        let recognizedText = observations.compactMap { observation in
                            observation.topCandidates(1).first?.string
                        }
                        
                        // Look for expiry date
                        let expiryKeywords = ["exp", "exp.", "exp date", "expiry", "expire", "expires", "expiration"]
                        
                        // Check lines with expiry keywords first
                        for line in recognizedText {
                            let lowercaseLine = line.lowercased()
                            
                            for keyword in expiryKeywords {
                                if lowercaseLine.contains(keyword) {
                                    if let date = dateExtractor.findDate(in: line) {
                                        if self.isReasonableDate(date) {
                                            bestDate = date
                                            break
                                        }
                                    }
                                }
                            }
                            
                            if bestDate != nil { break }
                        }
                        
                        // Then check all lines for dates
                        if bestDate == nil {
                            for line in recognizedText {
                                if line.count >= 4 && line.count <= 15 {
                                    if let date = dateExtractor.findDate(in: line) {
                                        if self.isReasonableDate(date) {
                                            bestDate = date
                                            break
                                        }
                                    }
                                }
                            }
                        }
                        
                        semaphore.signal()
                    }
                    
                    // Set recognition options
                    textRequest.recognitionLevel = .accurate
                    textRequest.usesLanguageCorrection = true
                    
                    // Perform request
                    do {
                        try requestHandler.perform([textRequest])
                    } catch {
                        print("Error in text recognition: \(error)")
                    }
                    
                    // Wait for processing to complete
                    semaphore.wait()
                    
                    // If we found a date, stop processing more images
                    if bestDate != nil {
                        break
                    }
                }
            }
            
            // Update result
            DispatchQueue.main.async {
                self.processingProgress = 1.0
                
                if let date = bestDate {
                    self.medicineResult.expirationDate = date
                }
                
                // Move to completion
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.currentStep = .complete
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func isReasonableDate(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        
        // Check if date is within reasonable range for medicine expiration
        let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now)!
        let sixYearsFromNow = calendar.date(byAdding: .year, value: 6, to: now)!
        
        return date >= threeMonthsAgo && date <= sixYearsFromNow
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// Direct scanner delegate
class DirectScannerDelegate: NSObject, VNDocumentCameraViewControllerDelegate {
    private let onScanComplete: (VNDocumentCameraScan) -> Void
    private let onCancel: () -> Void
    
    init(onScanComplete: @escaping (VNDocumentCameraScan) -> Void, onCancel: @escaping () -> Void) {
        self.onScanComplete = onScanComplete
        self.onCancel = onCancel
        super.init()
    }
    
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        controller.dismiss(animated: true) {
            self.onScanComplete(scan)
        }
    }
    
    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true) {
            self.onCancel()
        }
    }
    
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        controller.dismiss(animated: true) {
            print("Scanner error: \(error)")
            self.onCancel()
        }
    }
}
