import SwiftUI
import UIKit

struct ScannerOverlayView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Semi-transparent background
                Color.black.opacity(0.5)
                    .edgesIgnoringSafeArea(.all)
                
                // Cut out scanning rectangle
                Rectangle()
                    .fill(Color.clear)
                    .frame(
                        width: min(geometry.size.width * 0.8, 300),
                        height: min(geometry.size.width * 0.4, 150)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(colorScheme == .dark ? Color.white : Color.blue, lineWidth: 3)
                    )
                    .blendMode(.destinationOut)
                
                // Corner brackets
                CornerBracketsView(
                    width: min(geometry.size.width * 0.8, 300),
                    height: min(geometry.size.width * 0.4, 150)
                )
                .foregroundColor(colorScheme == .dark ? .white : .blue)
                
                // Instructions text
                VStack {
                    Spacer()
                    Text("Position barcode within frame")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.bottom, 50)
                }
            }
        }
        .compositingGroup()
    }
}

struct CornerBracketsView: View {
    let width: CGFloat
    let height: CGFloat
    let cornerLength: CGFloat = 20
    let lineWidth: CGFloat = 5
    
    var body: some View {
        ZStack {
            // Top Left
            Path { path in
                path.move(to: CGPoint(x: -width/2, y: -height/2 + cornerLength))
                path.addLine(to: CGPoint(x: -width/2, y: -height/2))
                path.addLine(to: CGPoint(x: -width/2 + cornerLength, y: -height/2))
            }
            .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            
            // Top Right
            Path { path in
                path.move(to: CGPoint(x: width/2 - cornerLength, y: -height/2))
                path.addLine(to: CGPoint(x: width/2, y: -height/2))
                path.addLine(to: CGPoint(x: width/2, y: -height/2 + cornerLength))
            }
            .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            
            // Bottom Left
            Path { path in
                path.move(to: CGPoint(x: -width/2, y: height/2 - cornerLength))
                path.addLine(to: CGPoint(x: -width/2, y: height/2))
                path.addLine(to: CGPoint(x: -width/2 + cornerLength, y: height/2))
            }
            .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            
            // Bottom Right
            Path { path in
                path.move(to: CGPoint(x: width/2 - cornerLength, y: height/2))
                path.addLine(to: CGPoint(x: width/2, y: height/2))
                path.addLine(to: CGPoint(x: width/2, y: height/2 - cornerLength))
            }
            .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        }
    }
}

// UIKit version for the UIViewController implementation
class ScannerOverlayUIView: UIView {
    private let scanRectWidth: CGFloat = 300
    private let scanRectHeight: CGFloat = 150
    private let cornerLength: CGFloat = 20
    private let lineWidth: CGFloat = 5
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // Draw semi-transparent background
        context.setFillColor(UIColor.black.withAlphaComponent(0.5).cgColor)
        context.fill(rect)
        
        // Calculate scan rectangle positioning
        let scanRectWidth = min(bounds.width * 0.8, 300)
        let scanRectHeight = min(bounds.width * 0.4, 150)
        let scanRect = CGRect(
            x: (bounds.width - scanRectWidth) / 2,
            y: (bounds.height - scanRectHeight) / 2,
            width: scanRectWidth,
            height: scanRectHeight
        )
        
        // Cut out the scan rectangle
        context.setBlendMode(.clear)
        UIBezierPath(roundedRect: scanRect, cornerRadius: 12).fill()
        
        // Draw rectangle outline
        context.setBlendMode(.normal)
        context.setStrokeColor(UIColor.systemBlue.cgColor)
        context.setLineWidth(3)
        UIBezierPath(roundedRect: scanRect, cornerRadius: 12).stroke()
        
        // Draw corner brackets
        context.setStrokeColor(UIColor.systemBlue.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        
        // Top Left
        context.beginPath()
        context.move(to: CGPoint(x: scanRect.minX, y: scanRect.minY + cornerLength))
        context.addLine(to: CGPoint(x: scanRect.minX, y: scanRect.minY))
        context.addLine(to: CGPoint(x: scanRect.minX + cornerLength, y: scanRect.minY))
        context.strokePath()
        
        // Top Right
        context.beginPath()
        context.move(to: CGPoint(x: scanRect.maxX - cornerLength, y: scanRect.minY))
        context.addLine(to: CGPoint(x: scanRect.maxX, y: scanRect.minY))
        context.addLine(to: CGPoint(x: scanRect.maxX, y: scanRect.minY + cornerLength))
        context.strokePath()
        
        // Bottom Left
        context.beginPath()
        context.move(to: CGPoint(x: scanRect.minX, y: scanRect.maxY - cornerLength))
        context.addLine(to: CGPoint(x: scanRect.minX, y: scanRect.maxY))
        context.addLine(to: CGPoint(x: scanRect.minX + cornerLength, y: scanRect.maxY))
        context.strokePath()
        
        // Bottom Right
        context.beginPath()
        context.move(to: CGPoint(x: scanRect.maxX - cornerLength, y: scanRect.maxY))
        context.addLine(to: CGPoint(x: scanRect.maxX, y: scanRect.maxY))
        context.addLine(to: CGPoint(x: scanRect.maxX, y: scanRect.maxY - cornerLength))
        context.strokePath()
        
        // Draw instruction text
        let instructionText = "Position barcode within frame"
        let font = UIFont.boldSystemFont(ofSize: 16)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white
        ]
        
        let textSize = instructionText.size(withAttributes: textAttributes)
        let textRect = CGRect(
            x: (bounds.width - textSize.width) / 2,
            y: scanRect.maxY + 20,
            width: textSize.width,
            height: textSize.height
        )
        
        instructionText.draw(in: textRect, withAttributes: textAttributes)
    }
}

/*
 struct ScannerOverlayView_Previews: PreviewProvider {
 static var previews: some View {
 ScannerOverlayView()
 }
 }
 */
