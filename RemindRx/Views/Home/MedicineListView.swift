import SwiftUI

struct MedicineListView: View {
    @EnvironmentObject var medicineStore: MedicineStore
    @State private var showScannerSheet = false
    @State private var showAddMedicineForm = false
    @State private var showingDeleteAllConfirmation = false
    @State private var showExpiredOnly = false
    
    var body: some View {
        VStack(spacing: 0) {
                // Filter toggle
                HStack {
                    Toggle("Show Expired Only", isOn: $showExpiredOnly)
                        .padding(.horizontal)
                        .toggleStyle(SwitchToggleStyle(tint: .red))
                }
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                
                // Medicine list
                List {
                    ForEach(filteredMedicines) { medicine in
                        MedicineTileView(medicine: medicine)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    medicineStore.delete(medicine)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("RemindRx")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingDeleteAllConfirmation = true
                    } label: {
                        Label("Clear All", systemImage: "trash")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showScannerSheet = true
                        } label: {
                            Label("Scan Barcode", systemImage: "barcode.viewfinder")
                        }
                        
                        Button {
                            showAddMedicineForm = true
                        } label: {
                            Label("Add Manually", systemImage: "square.and.pencil")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showScannerSheet) {
                BarcodeScannerView { result in
                    self.showScannerSheet = false
                    switch result {
                    case .success(let barcode):
                        medicineStore.lookupDrug(barcode: barcode) { result in
                            DispatchQueue.main.async {
                                switch result {
                                case .success(let medicine):
                                    // Pre-populate form with found data
                                    let editableMedicine = medicine
                                    self.showAddMedicineForm = true
                                    self.medicineStore.draftMedicine = editableMedicine
                                case .failure:
                                    // Show empty form for manual entry
                                    self.showAddMedicineForm = true
                                    self.medicineStore.draftMedicine = Medicine(
                                        name: "",
                                        description: "",
                                        manufacturer: "",
                                        type: .otc,
                                        alertInterval: .week,
                                        expirationDate: Date().addingTimeInterval(60*60*24*90),
                                        barcode: barcode
                                    )
                                }
                            }
                        }
                    case .failure:
                        // Show empty form for manual entry on scan failure
                        self.showAddMedicineForm = true
                        self.medicineStore.draftMedicine = Medicine(
                            name: "",
                            description: "",
                            manufacturer: "",
                            type: .otc,
                            alertInterval: .week,
                            expirationDate: Date().addingTimeInterval(60*60*24*90)
                        )
                    }
                }
            }
            .sheet(isPresented: $showAddMedicineForm) {
                MedicineFormView(isPresented: $showAddMedicineForm)
            }
            .alert("Delete All Medicines", isPresented: $showingDeleteAllConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete All", role: .destructive) {
                    medicineStore.deleteAll()
                }
            } message: {
                Text("Are you sure you want to delete all medicines? This action cannot be undone.")
            }
    }
    
    var filteredMedicines: [Medicine] {
        if showExpiredOnly {
            return medicineStore.medicines.filter { $0.expirationDate < Date() }
        } else {
            return medicineStore.medicines
        }
    }
}
