import SwiftUI

struct MedicineTileView: View {
    let medicine: Medicine
    @EnvironmentObject var medicineStore: MedicineStore
    
    // Format date helper function
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    // Check if expired
    private var isExpired: Bool {
        return medicine.expirationDate < Date()
    }
    
    // Check if expiring soon
    private var isExpiringSoon: Bool {
        let timeInterval = medicine.expirationDate.timeIntervalSince(Date())
        return timeInterval > 0 && timeInterval < Double(medicine.alertInterval.days * 24 * 60 * 60)
    }
    
    var body: some View {
        NavigationLink(destination: MedicineDetailView(medicine: medicine)) {
            HStack {
                VStack(alignment: .leading) {
                    Text(medicine.name)
                        .font(.headline)
                    
                    Text("Expires: \(formatDate(medicine.expirationDate))")
                        .font(.subheadline)
                        .foregroundColor(isExpired ? .red : .secondary)
                }
                
                Spacer()
                
                if isExpiringSoon && !isExpired {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.yellow)
                } else if isExpired {
                    ExpiryBadgeView(status: .expired, compact: true)
                }
            }
            .padding(.vertical, 4)
        }
        // Add a stable ID to ensure SwiftUI can track this view properly
        .id("medicine-tile-\(medicine.id.uuidString)")
    }
}
