import SwiftUI
import AVFoundation
import Combine

class ScannerViewModel: ObservableObject {
    enum ScannerState {
        case idle
        case scanning
        case processing
        case success(String)
        case error(Error)
    }
    
    enum ScannerError: Error, LocalizedError {
        case cameraPermissionDenied
        case invalidBarcode
        case scanningFailed
        
        var errorDescription: String? {
            switch self {
            case .cameraPermissionDenied:
                return "Camera access denied. Please enable camera access in Settings."
            case .invalidBarcode:
                return "Could not read barcode. Please try again."
            case .scanningFailed:
                return "Scanning failed. Please try again."
            }
        }
    }
    
    @Published var scannerState: ScannerState = .idle
    @Published var lastScannedBarcode: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        checkCameraPermission()
    }
    
    func startScanning() {
        scannerState = .scanning
    }
    
    func stopScanning() {
        if case .scanning = scannerState {
            scannerState = .idle
        }
    }
    
    func processBarcode(_ barcode: String) {
        scannerState = .processing
        
        // Validate barcode format
        if isValidBarcode(barcode) {
            lastScannedBarcode = barcode
            scannerState = .success(barcode)
        } else {
            scannerState = .error(ScannerError.invalidBarcode)
        }
    }
    
    func handleScanError(_ error: Error) {
        scannerState = .error(error)
    }
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // Already authorized
            break
            
        case .notDetermined:
            // Request permission
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if !granted {
                        self?.scannerState = .error(ScannerError.cameraPermissionDenied)
                    }
                }
            }
            
        case .denied, .restricted:
            scannerState = .error(ScannerError.cameraPermissionDenied)
            
        @unknown default:
            break
        }
    }
    
    // MARK: - Helper Methods
    
    private func isValidBarcode(_ barcode: String) -> Bool {
        // Basic validation - can be expanded for specific barcode types
        // EAN-13, UPC-A are common for drugs (12-13 digits)
        // Also allow other formats like Code 128
        let trimmedBarcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if barcode has at least some characters
        guard !trimmedBarcode.isEmpty else {
            return false
        }
        
        // For numeric barcodes (EAN, UPC), verify they only contain digits
        if CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: trimmedBarcode)) {
            // Common retail barcode lengths
            let validLengths = [8, 12, 13, 14]
            return validLengths.contains(trimmedBarcode.count)
        }
        
        // For Code 128, Code 39, etc., just ensure reasonable length
        return trimmedBarcode.count > 3 && trimmedBarcode.count < 50
    }
    
    // Reset after error
    func resetFromError() {
        scannerState = .idle
    }
}
