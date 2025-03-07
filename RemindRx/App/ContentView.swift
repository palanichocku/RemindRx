import SwiftUI

struct ContentView: View {
    @EnvironmentObject var medicineStore: MedicineStore
    @State public var selectedTab = 0
    @State public var showScannerSheet = false
    @State public var showAddMedicineForm = false
    @State public var showTrackingView = false
    @State public var showFeatureInDevelopment = false
    @State public var inDevelopmentFeature = ""
    @State public var showingTestDataGenerator: Bool = false
    
    // Add refresh state
    @State private var dashboardRefreshTrigger = UUID()
    
    private func refreshAllData() {
        // Force a refresh of all data
        medicineStore.loadMedicines()
        
        // You could also add code to refresh any other data stores here
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
                            case .failure(let error):
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
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack {
                    Text("RemindRx")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primaryFallback())
                    
                    Text("Medicine Management")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                // Main dashboard with icons
                ScrollView {
                    VStack(spacing: 20) {
                        // Main action buttons grid
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 20) {
                            // Scan button
                            DashboardButton(
                                title: "Scan",
                                description: "Scan medicine barcode",
                                icon: "barcode.viewfinder",
                                iconColor: .blue,
                                action: {
                                    showScannerSheet = true
                                }
                            )
                            
                            // Track button
                            DashboardButton(
                                title: "Track",
                                description: "Track medication adherence",
                                icon: "list.bullet.clipboard",
                                iconColor: .green,
                                action: {
                                    showTrackingView = true
                                }
                            )
                            
                            // Report button
                            DashboardButton(
                                title: "Report",
                                description: "View medication reports",
                                icon: "chart.bar.doc.horizontal",
                                iconColor: .orange,
                                action: {
                                    inDevelopmentFeature = "Medication Reports"
                                    showFeatureInDevelopment = true
                                }
                            )
                            
                            // Refill button
                            DashboardButton(
                                title: "Refill",
                                description: "Manage medication refills",
                                icon: "arrow.clockwise.circle",
                                iconColor: .purple,
                                action: {
                                    inDevelopmentFeature = "Medication Refills"
                                    showFeatureInDevelopment = true
                                }
                            )
                            
                        }
                        .padding(.horizontal)
                        
                        Divider()
                            .padding(.vertical, 10)
                        
                        // Medicine list section
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("My Medicines")
                                    .font(.headline)
                                
                                Spacer()
                                
                                NavigationLink(destination: MedicineListView()) {
                                    Text("See All")
                                        .font(.subheadline)
                                        .foregroundColor(AppColors.primaryFallback())
                                }
                            }
                            .padding(.horizontal)
                            
                            // Show recent medicines
                            if medicineStore.medicines.isEmpty {
                                EmptyMedicinesView()
                            } else {
                                RecentMedicinesView().id(dashboardRefreshTrigger) // Force refresh
                            }
                        }
                        #if DEBUG
                        // Add the developer menu for testing
                        Spacer()
                        setupDeveloperMenu()
                        #endif
                    }
                    .padding(.vertical)
                }
                
                //Spacer()
            }
            // Force refresh when appearing
            .onAppear {
                dashboardRefreshTrigger = UUID()
                medicineStore.loadMedicines()
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showScannerSheet) {
                scannerSheet
            }
            .sheet(isPresented: $showAddMedicineForm) {
                MedicineFormView(isPresented: $showAddMedicineForm)
            }
            .sheet(isPresented: $showTrackingView) {
                AdherenceTrackingView()
            }
            .alert(isPresented: $showFeatureInDevelopment) {
                Alert(
                    title: Text("Coming Soon"),
                    message: Text("\(inDevelopmentFeature) feature is currently under development and will be available in a future update."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .accentColor(AppColors.primaryFallback())
        .onAppear {
            //Load medicines when app appears
            dashboardRefreshTrigger = UUID()
            medicineStore.loadMedicines()
        }
        // Listen for data change notifications
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MedicineDataChanged"))) { _ in
            // Update dashboard when data changes
            dashboardRefreshTrigger = UUID()
            medicineStore.loadMedicines()
        }
    }
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistentContainer.shared.viewContext
        let medicineStore = MedicineStore(context: context)
        
        ContentView()
            .environment(\.managedObjectContext, context)
            .environmentObject(medicineStore)
    }
}
