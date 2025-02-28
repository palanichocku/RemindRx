import SwiftUI

struct ContentView: View {
    @EnvironmentObject var medicineStore: MedicineStore
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                MedicineListView()
                    .navigationTitle("RemindRx")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Image(systemName: AppImages.homeTab)
                Text("Medicines")
            }
            .tag(0)
            
            NavigationView {
                QuickScanView()
                    .navigationTitle("Quick Scan")
            }
            .tabItem {
                Image(systemName: AppImages.scanTab)
                Text("Scan")
            }
            .tag(1)
            
            NavigationView {
                AboutView()
                    .navigationTitle("About")
            }
            .tabItem {
                Image(systemName: AppImages.aboutTab)
                Text("About")
            }
            .tag(2)
        }
        .accentColor(AppColors.primaryFallback())
        .onAppear {
            // Load medicines when app appears
            medicineStore.loadMedicines()
            
            // Set tab bar appearance
            setTabBarAppearance()
        }
    }
    
    private func setTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

struct QuickScanView: View {
    @EnvironmentObject var medicineStore: MedicineStore
    @State private var showScannerSheet = false
    @State private var showAddMedicineForm = false
    @State private var scanError: String?
    @State private var showError = false
    
    var body: some View {
        VStack {
            Spacer()
            
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 120))
                .foregroundColor(AppColors.primaryFallback())
                .padding()
            
            Text("Scan Medicine Barcode")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 5)
            
            Text("Quickly scan a medicine barcode to add it to your collection.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            
            Button(action: {
                showScannerSheet = true
            }) {
                HStack {
                    Image(systemName: "barcode.viewfinder")
                    Text("Scan Barcode")
                }
                .frame(minWidth: 200)
                .padding()
                .background(AppColors.primaryFallback())
                .foregroundColor(.white)
                .cornerRadius(AppConstants.cornerRadius)
            }
            .accessibilityIdentifier(AccessibilityIDs.scanButton)
            
            Button(action: {
                // Reset draft and show form
                medicineStore.draftMedicine = nil
                showAddMedicineForm = true
            }) {
                HStack {
                    Image(systemName: "square.and.pencil")
                    Text("Add Manually")
                }
                .frame(minWidth: 200)
                .padding()
                .background(Color.clear)
                .foregroundColor(AppColors.primaryFallback())
                .overlay(
                    RoundedRectangle(cornerRadius: AppConstants.cornerRadius)
                        .stroke(AppColors.primaryFallback(), lineWidth: 1)
                )
            }
            .padding(.top, 10)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Quick Scan")
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
                                // First show error message
                                self.scanError = "Barcode lookup failed: Please enter medicine details manually."
                                self.showError = true
                                // After dismissing the error, the form will show
                            }
                        }
                    }
                case .failure(let error):
                    // Show error for scanner failure
                    self.scanError = "Scanner error: Please enter medicine details manually."
                    self.showError = true
                }
            }
        }
        .sheet(isPresented: $showAddMedicineForm) {
            MedicineFormView(isPresented: $showAddMedicineForm)
        }
        .alert(AppStrings.lookupFailedTitle, isPresented: $showError) {
            Button("OK", role: .cancel) {
                // Show the form after user acknowledges the error
                if self.medicineStore.draftMedicine != nil {
                    self.showAddMedicineForm = true
                }
            }
        } message: {
            Text(scanError ?? AppStrings.lookupFailedMessage)
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
