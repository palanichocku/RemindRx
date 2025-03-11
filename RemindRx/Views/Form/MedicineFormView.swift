import SwiftUI

public struct MedicineFormView: View {
    @EnvironmentObject var medicineStore: MedicineStore
    @Binding var isPresented: Bool
    
    // Form fields
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var manufacturer: String = ""
    @State private var type: Medicine.MedicineType = .otc
    @State private var selectedType: String
    @State private var alertInterval: Medicine.AlertInterval = .week
    @State private var expirationDate: Date = Date().addingTimeInterval(60*60*24*90) // 90 days
    @State private var barcode: String = ""
    @State private var source: String = "Manual Entry"
    
    // Form validation state
    @State private var nameError: String? = nil
    @State private var isSaving: Bool = false
    @State private var showSaveError: Bool = false
    @State private var saveErrorMessage: String = ""
    @State private var hasChanges: Bool = false
    @State private var showDiscardChangesAlert: Bool = false
    
    // Initialize with proper defaults
    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        self._selectedType = State(initialValue: Medicine.MedicineType.otc.rawValue)
    }
    
    // Computed property to check if editing or creating new
    private var isEditing: Bool {
        medicineStore.draftMedicine != nil
    }
    
    private var defaultBarcode: String {
        let timestamp = Int(Date().timeIntervalSince1970)
        return "RX\(timestamp)"
    }
    
    public var body: some View {
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
                
                // Use a more reliable approach for the type selection
                VStack(alignment: .leading, spacing: 6) {
                    Text("Type")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Use a custom segmented control implementation
                    HStack(spacing: 0) {
                        // OTC Button
                        Button(action: {
                            selectedType = Medicine.MedicineType.otc.rawValue
                            type = .otc
                            print("Selected type: \(selectedType)")
                            hasChanges = true
                        }) {
                            Text("OTC")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(selectedType == Medicine.MedicineType.otc.rawValue ?
                                    Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(selectedType == Medicine.MedicineType.otc.rawValue ?
                                    .white : .primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Prescription Button
                        Button(action: {
                            selectedType = Medicine.MedicineType.prescription.rawValue
                            type = .prescription
                            print("Selected type: \(selectedType)")
                            hasChanges = true
                        }) {
                            Text("Prescription")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(selectedType == Medicine.MedicineType.prescription.rawValue ?
                                    Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(selectedType == Medicine.MedicineType.prescription.rawValue ?
                                    .white : .primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .cornerRadius(8)
                }
                .padding(.vertical, 6)
            }
            
            // Barcode Section
            Section(header: Text("Barcode Information")) {
                HStack {
                    TextField("Barcode", text: $barcode)
                        .onChange(of: barcode) { _ in
                            hasChanges = true
                        }
                        .keyboardType(.numberPad)
                    
                    // Add a reset button to use default
                    if !barcode.isEmpty {
                        Button(action: {
                            barcode = defaultBarcode
                        }) {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                if barcode.isEmpty {
                    Text("Default barcode will be used")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                TextField("Source", text: $source)
                    .onChange(of: source) { _ in
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
            
            // If it's a new medicine with empty barcode, set a default
            if !isEditing && barcode.isEmpty {
                barcode = defaultBarcode
            }
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
        selectedType = draft.type.rawValue // Set the selectedType string
        alertInterval = draft.alertInterval
        expirationDate = draft.expirationDate
        barcode = draft.barcode ?? ""
        source = draft.source ?? "Manual Entry"
        
        // Reset change tracking
        hasChanges = false
        
        // Debug output
        print("Loaded medicine with type: \(type.rawValue), selectedType: \(selectedType)")
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
        
        // Ensure the type is set correctly based on the selected value
        if selectedType == Medicine.MedicineType.prescription.rawValue {
            type = .prescription
        } else {
            type = .otc
        }
        
        // Debug the type being saved
        print("Saving medicine with type: \(type.rawValue), selectedType: \(selectedType)")
        
        // Create medicine object
        var medicine: Medicine
        
        // Make sure barcode is not empty
        let finalBarcode = barcode.isEmpty ? generateBarcode() : barcode
        
        if isEditing, let draft = medicineStore.draftMedicine {
            // Update existing draft
            medicine = draft
            medicine.name = name
            medicine.description = description
            medicine.manufacturer = manufacturer
            medicine.type = type
            medicine.alertInterval = alertInterval
            medicine.expirationDate = expirationDate
            medicine.barcode = finalBarcode
            medicine.source = source
        } else {
            // Create new medicine
            medicine = Medicine(
                name: name,
                description: description,
                manufacturer: manufacturer,
                type: type,
                alertInterval: alertInterval,
                expirationDate: expirationDate,
                dateAdded: Date(),
                barcode: finalBarcode,
                source: source
            )
        }
        
        // Save on main thread
        DispatchQueue.main.async {
            // Try to save
            medicineStore.save(medicine)
            
            // Update UI
            self.isSaving = false
            self.isPresented = false
        }
    }
    
    /// Generate a unique barcode for medicines without one
    private func generateBarcode() -> String {
        let timestamp = Date().timeIntervalSince1970
        let random = Int.random(in: 1000...9999)
        return "GEN\(Int(timestamp))\(random)"
    }
    
    /// Discard changes and dismiss the form
    private func discardAndDismiss() {
        medicineStore.draftMedicine = nil
        isPresented = false
    }
}
