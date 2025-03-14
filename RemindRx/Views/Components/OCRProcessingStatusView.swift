import SwiftUI

/// Status view shown during OCR processing
struct OCRProcessingStatusView: View {
    let phase: OCRProcessingPhase
    let progress: Double
    
    enum OCRProcessingPhase {
        case scanning
        case analyzing
        case extractingText
        case findingExpirationDate
        case complete
        case failed
        
        var description: String {
            switch self {
            case .scanning:
                return "Scanning document..."
            case .analyzing:
                return "Analyzing image..."
            case .extractingText:
                return "Extracting medicine details..."
            case .findingExpirationDate:
                return "Looking for expiration date..."
            case .complete:
                return "Complete!"
            case .failed:
                return "Processing failed"
            }
        }
        
        var icon: String {
            switch self {
            case .scanning:
                return "doc.viewfinder"
            case .analyzing, .extractingText, .findingExpirationDate:
                return "text.magnifyingglass"
            case .complete:
                return "checkmark.circle"
            case .failed:
                return "exclamationmark.triangle"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: phase.icon)
                .font(.system(size: 48))
                .foregroundColor(phase == .failed ? .red : .blue)
            
            // Status text
            Text(phase.description)
                .font(.headline)
            
            // Progress indicator
            if phase != .complete && phase != .failed {
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(width: 200)
            }
        }
        .padding(32)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
    }
}

/// View to show OCR results preview before adding to medicine form
struct OCRResultPreviewView: View {
    // Import the OCRResult type from OCRProcessingService or use the same definition
    // But reference the structure properly to avoid ambiguity
    let result: OCRResult  // From OCRProcessingService
    let onConfirm: () -> Void
    let onEdit: () -> Void
    let onCancel: () -> Void
    
    @State private var isPrescription: Bool
    
    init(result: OCRResult, onConfirm: @escaping () -> Void, onEdit: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.result = result
        self.onConfirm = onConfirm
        self.onEdit = onEdit
        self.onCancel = onCancel
        self._isPrescription = State(initialValue: result.isPrescription)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Detected Medicine Details")) {
                    if !result.name.isEmpty {
                        HStack {
                            Text("Name")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(result.name)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.trailing)
                        }
                    } else {
                        HStack {
                            Text("Name")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Not detected")
                                .foregroundColor(.red)
                                .italic()
                        }
                    }
                    
                    if !result.manufacturer.isEmpty {
                        HStack {
                            Text("Manufacturer")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(result.manufacturer)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    
                    if !result.description.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .foregroundColor(.secondary)
                            Text(result.description)
                                .foregroundColor(.primary)
                                .lineLimit(3)
                        }
                    }
                    
                    Toggle("Prescription Medication", isOn: $isPrescription)
                    
                    if let expirationDate = result.expirationDate {
                        HStack {
                            Text("Expiration Date")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatDate(expirationDate))
                                .foregroundColor(.primary)
                        }
                    } else {
                        HStack {
                            Text("Expiration Date")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Not detected")
                                .foregroundColor(.red)
                                .italic()
                        }
                    }
                    
                    if let barcode = result.barcode {
                        HStack {
                            Text("Barcode")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(barcode)
                                .foregroundColor(.primary)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                }
                
                Section(footer: Text("You can edit these details in the next screen")) {
                    Button(action: {
                        onConfirm()
                    }) {
                        Text("Use These Details")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: {
                        onEdit()
                    }) {
                        Text("Edit Details")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    
                    Button(action: {
                        onCancel()
                    }) {
                        Text("Cancel")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("OCR Results")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// Preview providers
struct OCRProcessingStatusView_Previews: PreviewProvider {
    static var previews: some View {
        OCRProcessingStatusView(
            phase: .extractingText,
            progress: 0.6
        )
        .previewLayout(.sizeThatFits)
        .padding()
        .background(Color.gray.opacity(0.2))
    }
}
