import SwiftUI

struct MedicineTileView: View {
    // Make this an observed object so it reloads
    //@ObservedObject var medicineStore: MedicineStore
    
    // Direct medicine reference
    let medicine: Medicine
    @EnvironmentObject var medicineStore: MedicineStore
    
    var body: some View {
        // Create a computed property for the actual medicine data
        let currentMedicine = getMostCurrentMedicine()
        
        NavigationLink(destination: MedicineDetailView(medicine: medicine)) {
            HStack {
                VStack(alignment: .leading) {
                    Text(currentMedicine.name)
                        .font(.headline)
                    
                    Text("Expires: \(formatDate(currentMedicine.expirationDate))")
                        .font(.subheadline)
                        .foregroundColor(isExpired(currentMedicine) ? .red : .secondary)
                }
                
                Spacer()
                
                if isExpiringSoon(currentMedicine) && !isExpired(currentMedicine) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.yellow)
                }
            }
            .padding(.vertical, 4)
        }
        // This key modifier forces a refresh when any medicine data changes
        .id("medicine-\(medicine.id)-\(medicineStore.lastUpdateTime)")
    }
    
    // Use the medicine ID to get the most current data
    private func getMostCurrentMedicine() -> Medicine {
        if let current = medicineStore.medicines.first(where: { $0.id == medicine.id }) {
            return current
        }
        return medicine
    }
    
    private func isExpired(_ medicine: Medicine) -> Bool {
        return medicine.expirationDate < Date()
    }
        
    private func isExpiringSoon(_ medicine: Medicine) -> Bool {
        let timeInterval = medicine.expirationDate.timeIntervalSince(Date())
        return timeInterval > 0 && timeInterval < Double(medicine.alertInterval.days * 24 * 60 * 60)
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
