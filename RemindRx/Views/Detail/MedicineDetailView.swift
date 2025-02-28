import SwiftUI

struct MedicineDetailView: View {
    @EnvironmentObject var medicineStore: MedicineStore
    @Environment(\.presentationMode) var presentationMode
    
    let medicine: Medicine
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header section
                HStack {
                    VStack(alignment: .leading) {
                        Text(medicine.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(medicine.manufacturer)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Medicine type badge
                    Text(medicine.type.rawValue)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(medicine.type == .prescription ? Color.blue : Color.green)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                
                Divider()
                
                // Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.headline)
                    
                    Text(medicine.description)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Expiration details
                VStack(alignment: .leading, spacing: 8) {
                    Text("Expiration")
                        .font(.headline)
                    
                    HStack {
                        Image(systemName: isExpired ? "calendar.badge.exclamationmark" : "calendar")
                            .foregroundColor(isExpired ? .red : .primary)
                        
                        Text(formatDate(medicine.expirationDate))
                            .foregroundColor(isExpired ? .red : .primary)
                            .fontWeight(isExpired ? .bold : .regular)
                        
                        if isExpired {
                            Text("EXPIRED")
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        } else if isExpiringSoon {
                            Text("EXPIRING SOON")
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.yellow)
                                .foregroundColor(.black)
                                .clipShape(Capsule())
                        }
                    }
                }
                
                Divider()
                
                // Alert settings
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reminder")
                        .font(.headline)
                    
                    HStack {
                        Image(systemName: "bell")
                        Text("Alert \(medicine.alertInterval.rawValue) expiration")
                    }
                }
                
                if medicine.barcode != nil {
                    Divider()
                    
                    // Barcode information
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Barcode")
                            .font(.headline)
                        
                        Text(medicine.barcode ?? "")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                // Added date
                VStack(alignment: .leading, spacing: 8) {
                    Text("Added")
                        .font(.headline)
                    
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                        Text(formatDate(medicine.dateAdded))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .alert("Delete Medicine", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                medicineStore.delete(medicine)
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("Are you sure you want to delete \(medicine.name)? This action cannot be undone.")
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
