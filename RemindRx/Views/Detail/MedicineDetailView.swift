import SwiftUI

struct MedicineDetailView: View {
    @EnvironmentObject var medicineStore: MedicineStore
    @Environment(\.presentationMode) var presentationMode
    
    //@State private var medicine: Medicine
    @State private var showingDeleteConfirmation = false
    @State private var isEditingExpiry = false
    @State private var editedExpirationDate: Date
    @State private var editedAlertInterval: Medicine.AlertInterval
    
    
    // Change to a local variable that won't be persisted across navigations
    private let medicineId: UUID
    
    // Computed property to always get the fresh data
    private var medicine: Medicine {
        medicineStore.medicines.first { $0.id == medicineId } ?? Medicine(
            name: "",
            description: "",
            manufacturer: "",
            type: .otc,
            alertInterval: .week,
            expirationDate: Date()
        )
    }
    
    // Initialize with just the ID
    init(medicine: Medicine) {
        self.medicineId = medicine.id
        // Initialize the state properties with the current values
        _editedExpirationDate = State(initialValue: medicine.expirationDate)
        _editedAlertInterval = State(initialValue: medicine.alertInterval)
    }
    
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
                
                // Expiration and Alert section - now with edit button
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(isEditingExpiry ? "Edit Expiration & Reminder" : "Expiration & Reminder")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: {
                            isEditingExpiry.toggle()
                        }) {
                            Text(isEditingExpiry ? "Done" : "Edit")
                                .foregroundColor(AppColors.primaryFallback())
                        }
                    }
                    
                    if isEditingExpiry {
                        // Editable version - both expiration and alert
                        VStack(alignment: .leading, spacing: 12) {
                            // Expiration date picker
                            DatePicker("Expiration Date", selection: $editedExpirationDate, displayedComponents: .date)
                                .datePickerStyle(DefaultDatePickerStyle())
                                .padding(.vertical, 4)
                            
                            // Alert interval picker
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Alert Interval")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Picker("Alert", selection: $editedAlertInterval) {
                                    ForEach(Medicine.AlertInterval.allCases, id: \.self) { interval in
                                        Text(interval.rawValue).tag(interval)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                            }
                            
                            // Save button
                            Button(action: saveChanges) {
                                Text("Save Changes")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(AppColors.primaryFallback())
                                    .cornerRadius(10)
                            }
                            .padding(.top, 8)
                        }
                    } else {
                        // Display-only version
                        VStack(alignment: .leading, spacing: 12) {
                            // Expiration date display
                            HStack {
                                Image(systemName: isExpired ? "calendar.badge.exclamationmark" : "calendar")
                                    .foregroundColor(isExpired ? .red : .primary)
                                
                                Text("Expires: \(formatDate(medicine.expirationDate))")
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
                            
                            // Alert interval display
                            HStack {
                                Image(systemName: "bell")
                                Text("Alert: \(medicine.alertInterval.rawValue) before expiration")
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                }
                
                Divider()
                
                // Source information (new)
                if medicine.source != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Source")
                            .font(.headline)
                        
                        HStack {
                            Image(systemName: "network")
                            Text(medicine.source ?? "Unknown")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                }
                
                // Barcode information
                if medicine.barcode != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Barcode")
                            .font(.headline)
                        
                        Text(medicine.barcode ?? "")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                }
                
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
        .navigationBarBackButtonHidden(true) // Add this to hide the default back button
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                    // Back button with forced refresh
                    Button {
                        medicineStore.loadMedicines()
                        medicineStore.notifyDataChanged()
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
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
        .onAppear {
            // Update the editable fields with fresh data whenever the view appears
            let currentMedicine = medicine
            editedExpirationDate = currentMedicine.expirationDate
            editedAlertInterval = currentMedicine.alertInterval
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
    
    func saveChanges() {
        // Debug logging
        print("MedicineDetailView: ===== SAVE CHANGES =====")
        print("MedicineDetailView: Original medicine expiration: \(formatDate(medicine.expirationDate))")
        print("MedicineDetailView: Edited expiration date: \(formatDate(editedExpirationDate))")
        
        // Create updated medicine with edited values
        var updatedMedicine = medicine
        updatedMedicine.expirationDate = editedExpirationDate
        updatedMedicine.alertInterval = editedAlertInterval
        
        // Save the updated medicine
        medicineStore.save(updatedMedicine)
        
        // This is the key part - we only need one notification approach
        // Force a reload and notify other views with small delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Reload fresh data
            self.medicineStore.loadMedicines()
            
            // Notify other views to refresh
            NotificationCenter.default.post(
                name: NSNotification.Name("MedicineDataChanged"),
                object: nil
            )
            
            // Exit edit mode
            self.isEditingExpiry = false
        }
        
        // Debug verification
        print("MedicineDetailView: Updated medicine: \(updatedMedicine.name) with new expiration date: \(formatDate(updatedMedicine.expirationDate))")
    }
}
