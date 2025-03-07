import SwiftUI

struct MedicineFormView: View {
    @EnvironmentObject var medicineStore: MedicineStore
    @Binding var isPresented: Bool
    
    // Form fields
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var manufacturer: String = ""
    @State private var type: Medicine.MedicineType = .otc
    @State private var alertInterval: Medicine.AlertInterval = .week
    @State private var expirationDate: Date = Date().addingTimeInterval(60*60*24*90) // 90 days
    @State private var barcode: String? = nil
    
    // Form validation state
    @State private var nameError: String? = nil
    @State private var isSaving: Bool = false
    @State private var showSaveError: Bool = false
    @State private var saveErrorMessage: String = ""
    @State private var hasChanges: Bool = false
    @State private var showDiscardChangesAlert: Bool = false
    
    // Computed property to check if editing or creating new
    private var isEditing: Bool {
        medicineStore.draftMedicine != nil
    }
    
    var body: some View {
        Form {
            // Medicine Information Section
            Section(header: Text("Medicine Information")) {
                // Name field with validation
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Name", text: $name)
                        .onChange(of: name) { _ in
                            validateName()
                            hasChanges = true
                        }
                    
                    if let error = nameError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                TextField("Manufacturer", text: $manufacturer)
                    .onChange(of: manufacturer) { _ in
                        hasChanges = true
                    }
                
                Picker("Type", selection: $type) {
                    ForEach(Medicine.MedicineType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: type) { _ in
                    hasChanges = true
                }
            }
            
            // Description Section
            Section(header: Text("Description")) {
                TextEditor(text: $description)
                    .frame(minHeight: 100)
                    .onChange(of: description) { _ in
                        hasChanges = true
                    }
            }
            
            // Expiration Section
            Section(header: Text("Expiration")) {
                DatePicker("Expiration Date", selection: $expirationDate, displayedComponents: .date)
                    .onChange(of: expirationDate) { _ in
                        hasChanges = true
                    }
                
                Picker("Alert", selection: $alertInterval) {
                    ForEach(Medicine.AlertInterval.allCases, id: \.self) { interval in
                        Text(interval.rawValue).tag(interval)
                    }
                }
                .onChange(of: alertInterval) { _ in
                    hasChanges = true
                }
            }
            
            // Barcode Section (if available)
            if let barcode = barcode, !barcode.isEmpty {
                Section(header: Text("Barcode")) {
                    Text(barcode)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Medicine" : "Add Medicine")
        .toolbar {
            // Cancel button
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    if hasChanges {
                        showDiscardChangesAlert = true
                    } else {
                        discardAndDismiss()
                    }
                }
            }
            
            // Save button
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveMedicine()
                }
                .disabled(name.isEmpty || isSaving)
            }
        }
        .onAppear {
            loadDraftMedicine()
        }
        .alert("Discard Changes?", isPresented: $showDiscardChangesAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Discard", role: .destructive) {
                discardAndDismiss()
            }
        } message: {
            Text("You have unsaved changes. Are you sure you want to discard them?")
        }
        .alert(isPresented: $showSaveError) {
            Alert(
                title: Text("Save Error"),
                message: Text(saveErrorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .overlay(
            // Loading overlay
            Group {
                if isSaving {
                    ZStack {
                        Color.black.opacity(0.4)
                            .edgesIgnoringSafeArea(.all)
                        
                        VStack(spacing: 15) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Saving...")
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
    
    // MARK: - Private Methods
    
    /// Load draft medicine data if editing an existing medicine
    private func loadDraftMedicine() {
        guard let draft = medicineStore.draftMedicine else {
            // No draft, using default values for new medicine
            return
        }
        
        // Populate form with draft medicine data
        name = draft.name
        description = draft.description
        manufacturer = draft.manufacturer
        type = draft.type
        alertInterval = draft.alertInterval
        expirationDate = draft.expirationDate
        barcode = draft.barcode
        
        // Reset change tracking
        hasChanges = false
    }
    
    /// Validate the medicine name
    private func validateName() {
        if name.isEmpty {
            nameError = "Name is required"
        } else if name.count < 2 {
            nameError = "Name must be at least 2 characters"
        } else {
            nameError = nil
        }
    }
    
    /// Save the medicine to the store
    private func saveMedicine() {
        // Validate input first
        validateName()
        
        if nameError != nil {
            // Don't proceed if there are validation errors
            return
        }
        
        isSaving = true
        
        // Create medicine object
        var medicine: Medicine
        
        if isEditing, let draft = medicineStore.draftMedicine {
            // Update existing draft
            medicine = draft
            medicine.name = name
            medicine.description = description
            medicine.manufacturer = manufacturer
            medicine.type = type
            medicine.alertInterval = alertInterval
            medicine.expirationDate = expirationDate
        } else {
            // Create new medicine
            medicine = Medicine(
                name: name,
                description: description,
                manufacturer: manufacturer,
                type: type,
                alertInterval: alertInterval,
                expirationDate: expirationDate,
                barcode: barcode
            )
        }
        
        // Save on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            // Try to save
            medicineStore.save(medicine)
            
            // Update UI on main thread
            DispatchQueue.main.async {
                isSaving = false
                medicineStore.draftMedicine = nil
                isPresented = false
            }
        }
    }
    
    /// Discard changes and dismiss the form
    private func discardAndDismiss() {
        medicineStore.draftMedicine = nil
        isPresented = false
    }
}
