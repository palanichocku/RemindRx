//
//  FixedDocumentScannerView.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/15/25.
//

import SwiftUI
import UIKit
import VisionKit

// This is a replacement for the document scanner view that explicitly handles presentation
struct FixedDocumentScannerView: UIViewControllerRepresentable {
    var onScan: (VNDocumentCameraScan) -> Void
    var onCancel: () -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        // Create a container view controller
        let containerVC = UIViewController()
        containerVC.view.backgroundColor = .clear
        
        // Present the scanner after a short delay to ensure proper context
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let scannerVC = VNDocumentCameraViewController()
            scannerVC.delegate = context.coordinator
            
            // Explicitly present as full screen
            scannerVC.modalPresentationStyle = .fullScreen
            containerVC.present(scannerVC, animated: true)
        }
        
        return containerVC
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
            print("Scanner error: \(error.localizedDescription)")
            onCancel()
        }
    }
}

// Helper to present view controllers with proper presentation
class ViewControllerPresenter {
    static func presentDocumentScanner(from viewController: UIViewController, delegate: VNDocumentCameraViewControllerDelegate) {
        let documentCameraViewController = VNDocumentCameraViewController()
        documentCameraViewController.delegate = delegate
        
        // Ensure we're on main thread
        DispatchQueue.main.async {
            viewController.present(documentCameraViewController, animated: true)
        }
    }
    
    static func presentViewControllerFromRoot(viewController: UIViewController) {
        if let rootVC = UIApplication.shared.windows.first?.rootViewController {
            // If there's already a presented VC, present from that
            let presentingVC = rootVC.presentedViewController ?? rootVC
            
            DispatchQueue.main.async {
                presentingVC.present(viewController, animated: true)
            }
        }
    }
}
