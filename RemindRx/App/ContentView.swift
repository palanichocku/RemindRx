import SwiftUI

struct ContentView: View {
    @EnvironmentObject var medicineStore: MedicineStore
    @EnvironmentObject var adherenceStore: AdherenceTrackingStore
    @State public var selectedTab = 0
    @State public var showScannerSheet = false
    @State public var showAddMedicineForm = false
    @State public var showTrackingView = false
    @State public var showReportView = false
    @State public var showRefillView = false
    @State public var showFeatureInDevelopment = false
    @State public var inDevelopmentFeature = ""
    @State public var showingTestDataGenerator: Bool = false
    
    // Add refresh state
    @State private var dashboardRefreshTrigger = UUID()
    
    private func refreshAllData() {
        // Force a refresh of all data
        medicineStore.loadMedicines()
        adherenceStore.refreshAllData()
    }
    
    var scannerSheet: some View {
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
                                self.medicineStore.draftMedicine = medicine
                                self.showAddMedicineForm = true
                            case .failure:
                                // Show empty form for manual entry
                                self.medicineStore.draftMedicine = Medicine(
                                    name: "",
                                    description: "",
                                    manufacturer: "",
                                    type: .otc,
                                    alertInterval: .week,
                                    expirationDate: Date().addingTimeInterval(Double(60*60*24*AppConstants.defaultExpirationDays)),
                                    barcode: barcode
                                )
                                
                                self.showAddMedicineForm = true
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
                        expirationDate: Date().addingTimeInterval(Double(60*60*24*AppConstants.defaultExpirationDays))
                    )
                }
            },
            onCancel: {
                self.showScannerSheet = false
            }
        )
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Dashboard Tab
            NavigationView {
                DashboardView()
            }
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }
            .tag(0)
            
            // Medicines Tab
            NavigationView {
                MedicineListView()
            }
            .tabItem {
                Image(systemName: "pills.fill")
                Text("Medicines")
            }
            .tag(1)
            
            // Tracking Tab
            NavigationView {
                AdherenceTrackingView()
            }
            .tabItem {
                Image(systemName: "checkmark.circle.fill")
                Text("Tracking")
            }
            .tag(2)
            
            // Settings Tab
            NavigationView {
                SettingsView()
            }
            .tabItem {
                Image(systemName: "gear")
                Text("Settings")
            }
            .tag(3)
        }
        .accentColor(AppColors.primaryFallback())
        // Force refresh when appearing
        .onAppear {
            dashboardRefreshTrigger = UUID()
            refreshAllData()
        }
        .sheet(isPresented: $showScannerSheet) {
            scannerSheet
        }
        .sheet(isPresented: $showAddMedicineForm) {
            MedicineFormView(isPresented: $showAddMedicineForm)
        }
        .sheet(isPresented: $showTrackingView) {
            DosageTrackingView()
        }
        .sheet(isPresented: $showReportView) {
            ReportView()
        }
        .sheet(isPresented: $showRefillView) {
            RefillManagementView()
        }
        .alert(isPresented: $showFeatureInDevelopment) {
            Alert(
                title: Text("Coming Soon"),
                message: Text("\(inDevelopmentFeature) feature is currently under development and will be available in a future update."),
                dismissButton: .default(Text("OK"))
            )
        }
        // Listen for data change notifications
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MedicineDataChanged"))) { _ in
            // Update dashboard when data changes
            dashboardRefreshTrigger = UUID()
            refreshAllData()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistentContainer.shared.viewContext
        let medicineStore = MedicineStore(context: context)
        let adherenceStore = AdherenceTrackingStore(context: context)
        
        ContentView()
            .environment(\.managedObjectContext, context)
            .environmentObject(medicineStore)
            .environmentObject(adherenceStore)
    }
}
