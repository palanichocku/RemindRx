import SwiftUI

struct ContentView: View {
    @EnvironmentObject var medicineStore: MedicineStore
    @State public var selectedTab = 0
    @State public var showScannerSheet = false
    @State public var showAddMedicineForm = false
    @State public var showFeatureInDevelopment = false
    @State public var inDevelopmentFeature = ""
    @State public var showingTestDataGenerator: Bool = false
    // Adding this line to force compilation

    // Add refresh state
    @State private var dashboardRefreshTrigger = UUID()

    private func refreshAllData() {
        // Force a refresh of all data
        medicineStore.loadMedicines()
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
                                    expirationDate: Date().addingTimeInterval(
                                        Double(
                                            60 * 60 * 24
                                                * AppConstants
                                                .defaultExpirationDays)),
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
                        expirationDate: Date().addingTimeInterval(
                            Double(
                                60 * 60 * 24
                                    * AppConstants.defaultExpirationDays))
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
                Text("Home_")
            }
            .tag(0)

            // Medicines Tab
            NavigationView {
                MedicineListView()
            }
            .tabItem {
                Image(systemName: "pills.fill")
                Text("Medicines_")
            }
            .tag(1)

            // New Tracking Tab
            NavigationView {
                MedicineTrackingView()
            }
            .tabItem {
                Image(systemName: "chart.bar.fill")
                Text("Tracking_")
            }
            .tag(2)

            // Settings Tab
            NavigationView {
                SettingsView()
            }
            .tabItem {
                Image(systemName: "gear")
                Text("Settings_")
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
        .sheet(isPresented: $showFeatureInDevelopment) {
            VStack(spacing: 20) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                    .padding()

                Text("Coming Soon")
                    .font(.title)
                    .fontWeight(.bold)

                Text(
                    "\(inDevelopmentFeature) feature is currently under development and will be available in a future update."
                )
                .multilineTextAlignment(.center)
                .padding()

                Button("Close") {
                    showFeatureInDevelopment = false
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding()
            }
            .padding()
        }
        // Listen for data change notifications
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSNotification.Name("MedicineDataChanged"))
        ) { _ in
            // Update dashboard when data changes
            dashboardRefreshTrigger = UUID()
            refreshAllData()
        }
    }

    #if DEBUG
        func setupDeveloperMenu() -> some View {
            VStack {
                #if DEBUG
                    Button(action: {
                        self.showingTestDataGenerator = true
                    }) {
                        HStack {
                            Image(systemName: "hammer.fill")
                            Text("Test Data Generator")
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.purple.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding(.bottom)
                #endif
            }
            .sheet(isPresented: $showingTestDataGenerator) {
                TestDataView()
                    .environmentObject(medicineStore)
            }
        }
    #endif
}
