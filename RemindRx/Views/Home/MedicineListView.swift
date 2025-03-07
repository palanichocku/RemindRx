import SwiftUI

struct MedicineListView: View {
    @EnvironmentObject var medicineStore: MedicineStore
    @State private var showScannerSheet = false
    @State private var showAddMedicineForm = false
    @State private var showingDeleteAllConfirmation = false
    @State private var showExpiredOnly = false
    // Add this state to track when to force refresh views
    @State private var refreshID = UUID()
    // Add this to track the observer
    @State private var observer: NSObjectProtocol?
    
    // Helper to format dates consistently
  private func formatDate(_ date: Date) -> String {
      let formatter = DateFormatter()
      formatter.dateStyle = .medium
      formatter.timeStyle = .none
      return formatter.string(from: date)
  }
    
    // Helper method to refresh data
    private func refreshData() {
        // Generate new UUID to force view refresh
        refreshID = UUID()
        
        // Load fresh data
        medicineStore.loadMedicines()
        
        // Debug print of all medicines for verification
        print("MEDICINE LIST REFRESH: \(medicineStore.medicines.count) medicines")
        for medicine in medicineStore.medicines {
            print("- \(medicine.name): Expires \(formatDate(medicine.expirationDate))")
        }
    }
    
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
                    // Back to the original implementation
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
            .id(refreshID) // This forces the entire list to rebuild
            //.onAppear {
            // Reload medicines when list appears
            //    medicineStore.loadMedicines()
            //}
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
            BarcodeScannerView(
                onScanCompletion: { result in
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
                },
                onCancel: {
                    self.showScannerSheet = false
                }
            )
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
        .onAppear {
            // Force refresh when view appears
            refreshData()
            
            // Set up the notification observer if not already set
            if observer == nil {
                observer = NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("MedicineDataChanged"),
                    object: nil,
                    queue: .main
                ) { _ in
                    refreshData()
                }
            }
        }
        .onDisappear {
            // Clean up observer when view disappears
            if let observer = observer {
                NotificationCenter.default.removeObserver(observer)
                self.observer = nil
            }
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
