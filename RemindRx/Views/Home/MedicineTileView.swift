import SwiftUI

struct MedicineTileView: View {
    let medicine: Medicine
    
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
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    var isExpired: Bool {
        medicine.expirationDate < Date()
    }
    
    var isExpiringSoon: Bool {
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
