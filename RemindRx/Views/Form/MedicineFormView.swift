import SwiftUI

struct MedicineFormView: View {
    @EnvironmentObject var medicineStore: MedicineStore
    @Binding var isPresented: Bool
    
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var manufacturer: String = ""
    @State private var type: Medicine.MedicineType = .otc
    @State private var alertInterval: Medicine.AlertInterval = .week
    @State private var expirationDate: Date = Date().addingTimeInterval(60*60*24*90) // 90 days from now
    
    var isEditing: Bool {
        medicineStore.draftMedicine != nil
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Medicine Information")) {
                    TextField("Name", text: $name)
                    
                    TextField("Manufacturer", text: $manufacturer)
                    
                    Picker("Type", selection: $type) {
                        ForEach(Medicine.MedicineType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Description")) {
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                }
                
                Section(header: Text("Expiration")) {
                    DatePicker("Expiration Date", selection: $expirationDate, displayedComponents: .date)
                }
                
                Section(header: Text("Reminder")) {
                    Picker("Alert", selection: $alertInterval) {
                        ForEach(Medicine.AlertInterval.allCases, id: \.self) { interval in
                            Text(interval.rawValue).tag(interval)
                        }
                    }
                }
                
                if isEditing, let barcode = medicineStore.draftMedicine?.barcode {
                    Section(header: Text("Barcode")) {
                        Text(barcode)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Medicine" : "Add Medicine")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        medicineStore.draftMedicine = nil
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveMedicine()
                        medicineStore.draftMedicine = nil
                        isPresented = false
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                // Populate form with draft medicine data if editing
                if let draft = medicineStore.draftMedicine {
                    name = draft.name
                    description = draft.description
                    manufacturer = draft.manufacturer
                    type = draft.type
                    alertInterval = draft.alertInterval
                    expirationDate = draft.expirationDate
                }
            }
        }
    }
    
    private func saveMedicine() {
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
                barcode: medicineStore.draftMedicine?.barcode
            )
        }
        
        medicineStore.save(medicine)
    }
}
