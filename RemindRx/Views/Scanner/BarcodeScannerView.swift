import SwiftUI
import AVFoundation

struct BarcodeScannerView: UIViewControllerRepresentable {
    var onScanCompletion: (Result<String, Error>) -> Void
    
    func makeUIViewController(context: Context) -> BarcodeScannerViewController {
        let viewController = BarcodeScannerViewController()
        viewController.delegate = context.coordinator
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: BarcodeScannerViewController, context: Context) {
        // Update the view controller if needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, BarcodeScannerViewControllerDelegate {
        private let parent: BarcodeScannerView
        
        init(_ parent: BarcodeScannerView) {
            self.parent = parent
        }
        
        func didScanBarcode(barcode: String) {
            parent.onScanCompletion(.success(barcode))
        }
        
        func didFailWithError(error: Error) {
            parent.onScanCompletion(.failure(error))
        }
    }
}

protocol BarcodeScannerViewControllerDelegate: AnyObject {
    func didScanBarcode(barcode: String)
    func didFailWithError(error: Error)
}

class BarcodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: BarcodeScannerViewControllerDelegate?
    
    enum ScannerError: Error {
        case cameraSetupFailed
        case invalidBarcode
    }
    
    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var overlayView: ScannerOverlayUIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCaptureSession()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if captureSession?.isRunning == false {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if captureSession?.isRunning == true {
            captureSession.stopRunning()
        }
    }
    
    private func setupCaptureSession() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .high
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            handleSetupError(ScannerError.cameraSetupFailed)
            return
        }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            } else {
                handleSetupError(ScannerError.cameraSetupFailed)
                return
            }
            
            let metadataOutput = AVCaptureMetadataOutput()
            
            if captureSession.canAddOutput(metadataOutput) {
                captureSession.addOutput(metadataOutput)
                
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [
                    .ean8,
                    .ean13,
                    .pdf417,
                    .qr,
                    .code128,
                    .code39,
                    .code93,
                    .upce
                ]
            } else {
                handleSetupError(ScannerError.cameraSetupFailed)
                return
            }
            
            setupPreviewLayer()
            setupOverlay()
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
            
        } catch {
            handleSetupError(error)
        }
    }
    
    private func setupPreviewLayer() {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.layer.bounds
        view.layer.addSublayer(previewLayer)
    }
    
    private func setupOverlay() {
        overlayView = ScannerOverlayUIView(frame: view.bounds)
        view.addSubview(overlayView)
    }
    
    private func handleSetupError(_ error: Error) {
        print("Scanner setup failed: \(error.localizedDescription)")
        delegate?.didFailWithError(error: error)
    }
    
    // MARK: - AVCaptureMetadataOutputObjectsDelegate
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else {
                return
            }
            
            guard let stringValue = readableObject.stringValue else {
                delegate?.didFailWithError(error: ScannerError.invalidBarcode)
                return
            }
            
            // Provide haptic feedback
            let feedbackGenerator = UINotificationFeedbackGenerator()
            feedbackGenerator.notificationOccurred(.success)
            
            captureSession.stopRunning()
            
            // Add small delay to ensure the user sees the successful scan
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.delegate?.didScanBarcode(barcode: stringValue)
            }
        }
    }
}
