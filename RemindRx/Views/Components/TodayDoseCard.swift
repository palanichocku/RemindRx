import SwiftUI

// Fix for the TodayDoseCard to make the Record button work
struct TodayDoseCard: View {
    let dose: AdherenceTrackingStore.TodayDose
    var onRecordTap: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(dose.medicine.name)
                    .font(.headline)
                
                Text(formatTime(dose.scheduledTime))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Status indicator
            statusView(dose.status)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .contentShape(Rectangle()) // Make entire card tappable
        .onTapGesture {
            onRecordTap()
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    @ViewBuilder
    private func statusView(_ status: MedicationDose.DoseStatus?) -> some View {
        if let status = status {
            switch status {
            case .taken:
                Label("Taken", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .missed:
                Label("Missed", systemImage: "xmark.circle.fill")
                    .foregroundColor(.red)
            case .skipped:
                Label("Skipped", systemImage: "minus.circle.fill")
                    .foregroundColor(.orange)
            }
        } else {
            // No status yet - Record button that directly opens the recording sheet
            Button(action: {
                onRecordTap() // Call the provided action
            }) {
                Text("Record")
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppColors.primaryFallback())
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle()) // Prevent any default button animations
        }
    }
}
