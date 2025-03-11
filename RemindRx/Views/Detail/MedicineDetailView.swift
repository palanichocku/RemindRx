import SwiftUI

struct MedicineDetailView: View {
    // Environment objects
    @EnvironmentObject var medicineStore: MedicineStore
    @Environment(\.presentationMode) var presentationMode
    
    // State variables
    @State private var medicine: Medicine
    @State private var showingDeleteConfirmation = false
    @State private var isEditingExpiry = false
    @State private var editedExpirationDate: Date
    @State private var editedAlertInterval: Medicine.AlertInterval
    @State private var showCreateScheduleSheet = false
    @State private var isSaving = false
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""
    
    // Initialization
    init(medicine: Medicine) {
        _medicine = State(initialValue: medicine)
        _editedExpirationDate = State(initialValue: medicine.expirationDate)
        _editedAlertInterval = State(initialValue: medicine.alertInterval)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header section
                headerSection
                
                Divider()
                
                // Description
                descriptionSection
                
                Divider()
                
                // Expiration and Alert section
                expirationSection
                
                Divider()
                
                // Source information
                if medicine.source != nil {
                    sourceSection
                    Divider()
                }
                
                // Barcode information
                if medicine.barcode != nil {
                    barcodeSection
                    Divider()
                }
                
                // Added date
                addedDateSection
                
                // Schedule section
                //Divider()
                //scheduleSection
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle(medicine.name)
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
        .alert(isPresented: $showSaveError) {
            Alert(
                title: Text("Save Error"),
                message: Text(saveErrorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $showCreateScheduleSheet) {
            NavigationView {
                // Replace with your actual schedule creation view
                Text("Schedule Creation View")
                    .navigationTitle("Create Schedule")
                    .navigationBarItems(trailing: Button("Done") {
                        showCreateScheduleSheet = false
                    })
            }
        }
        .onAppear {
            // Update with most current data when the view appears
            if let currentMedicine = medicineStore.getMedicine(byId: medicine.id) {
                self.medicine = currentMedicine
                self.editedExpirationDate = currentMedicine.expirationDate
                self.editedAlertInterval = currentMedicine.alertInterval
            }
        }
        .overlay(
            // Show loading overlay when saving
            Group {
                if isSaving {
                    ZStack {
                        Color.black.opacity(0.4)
                            .edgesIgnoringSafeArea(.all)
                        
                        VStack(spacing: 15) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Saving changes...")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding(25)
                        .background(Color(.systemGray3))
                        .cornerRadius(10)
                    }
                }
            }
        )
    }
    
    // MARK: - Section Views
    
    private var headerSection: some View {
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
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(.headline)
            
            Text(medicine.description.isEmpty ? "No description available" : medicine.description)
                .foregroundColor(.secondary)
        }
    }
    
    private var expirationSection: some View {
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
                    .disabled(isSaving)
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
    }
    
    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Source")
                .font(.headline)
            
            HStack {
                Image(systemName: "network")
                Text(medicine.source ?? "Unknown")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var barcodeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Barcode")
                .font(.headline)
            
            Text(medicine.barcode ?? "")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }
    
    private var addedDateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Added")
                .font(.headline)
            
            HStack {
                Image(systemName: "calendar.badge.plus")
                Text(formatDate(medicine.dateAdded))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    /*
    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Medication Schedule")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    showCreateScheduleSheet = true
                }) {
                    Text("Add Schedule")
                        .foregroundColor(AppColors.primaryFallback())
                }
            }
            
            Text("Create reminders for taking this medication regularly")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Placeholder for schedule list - implement with your actual schedule display
            Text("No schedules found")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
        }
    }
     */
    
    // MARK: - Helper Methods
    
    private var isExpired: Bool {
        return medicine.expirationDate < Date()
    }
    
    private var isExpiringSoon: Bool {
        let timeInterval = medicine.expirationDate.timeIntervalSince(Date())
        return timeInterval > 0 && timeInterval < Double(medicine.alertInterval.days * 24 * 60 * 60)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func saveChanges() {
        isSaving = true
        
        // Create updated medicine with edited values
        var updatedMedicine = medicine
        updatedMedicine.expirationDate = editedExpirationDate
        updatedMedicine.alertInterval = editedAlertInterval
        
        // Run save on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            // Save the updated medicine
            do {
                // Ensure we're on the main thread for UI updates
                DispatchQueue.main.async {
                    // Save the medicine
                    medicineStore.save(updatedMedicine)
                    
                    // Update local state
                    self.medicine = updatedMedicine
                    
                    // Exit edit mode and hide loading indicator
                    self.isEditingExpiry = false
                    self.isSaving = false
                }
            } catch {
                // Handle error on main thread
                DispatchQueue.main.async {
                    self.isSaving = false
                    self.saveErrorMessage = "Failed to save changes: \(error.localizedDescription)"
                    self.showSaveError = true
                }
            }
        }
    }
}
