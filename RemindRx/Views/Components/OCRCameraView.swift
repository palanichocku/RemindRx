//
//  OCRCameraView.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/14/25.
//

import SwiftUI
import UIKit
import Vision
import VisionKit

struct OCRCameraView: View {
    var onCapture: (OCRResult) -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var isShowingScanner = true
    @State private var isProcessing = false
    @State private var processingPhase: OCRProcessingStatusView.OCRProcessingPhase = .scanning
    @State private var processingProgress: Double = 0.0
    @State private var scannedResult: OCRResult?
    @State private var showResultPreview = false
    
    var body: some View {
        ZStack {
            // Background color
            Color(.systemBackground).edgesIgnoringSafeArea(.all)
            
            if isShowingScanner {
                // Show document scanner
                DocumentScannerView(
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
            } else if showResultPreview, let result = scannedResult {
                // Show result preview
                OCRResultPreviewView(
                    result: result,
                    onConfirm: {
                        // Use the detected details and return to form
                        presentationMode.wrappedValue.dismiss()
                        onCapture(result)
                    },
                    onEdit: {
                        // Return to form and let user edit
                        presentationMode.wrappedValue.dismiss()
                        onCapture(result)
                    },
                    onCancel: {
                        // Cancel OCR process
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
    }
    
    private func processDocumentScan(_ scan: VNDocumentCameraScan) {
        // Simulate processing phases with delays
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            processingPhase = .analyzing
            processingProgress = 0.3
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                processingPhase = .extractingText
                processingProgress = 0.6
                
                // Use the OCR processing service
                OCRProcessingService.shared.processDocumentScan(scan) { result in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        processingPhase = .findingExpirationDate
                        processingProgress = 0.9
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            // Processing complete
                            processingPhase = .complete
                            processingProgress = 1.0
                            scannedResult = result
                            
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
    }
}

/// A simple wrapper around VNDocumentCameraViewController
struct DocumentScannerView: UIViewControllerRepresentable {
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
