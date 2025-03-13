import SwiftUI
import CoreData
import UserNotifications

@main
struct RemindRxApp: App {
    // Use AppDelegate for notification delegate and Core Data
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Environment state - centralized stores that will be available throughout the app
    @StateObject private var medicineStore: MedicineStore
    
    // Initialize state objects
    init() {
        let context = PersistentContainer.shared.viewContext
        let medStore = MedicineStore(context: context)
        
        _medicineStore = StateObject(wrappedValue: medStore)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, PersistentContainer.shared.viewContext)
                .environmentObject(medicineStore)
                .onAppear {
                    // Request notification permissions when app launches
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                        if let error = error {
                            print("Error requesting notification permission: \(error)")
                        }
                    }
                    
                    // Initial data load
                    medicineStore.loadMedicines()
                }
        }
    }
}

// Main ContentView that manages the app's main interface
struct ContentView: View {
    @EnvironmentObject var medicineStore: MedicineStore
    @State private var selectedTab = 0
    @State private var showScannerSheet = false
    @State private var showAddMedicineForm = false
    @State private var showFeatureInDevelopment = false
    @State private var inDevelopmentFeature = ""
    @State private var showingTestDataGenerator: Bool = false
    @State private var dashboardRefreshTrigger = UUID()


    private func refreshAllData() {
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
                                        Double(60 * 60 * 24 * AppConstants.defaultExpirationDays)),
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
                            Double(60 * 60 * 24 * AppConstants.defaultExpirationDays))
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
                InsightsView()
            }
            .tabItem {
                Image(systemName: "chart.pie.fill")
                Text("Insights")
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
            // Place the ComingSoonView at the end so it overlays everything
            ComingSoonFeatureView(
                //isPresented: $showFeatureInDevelopment,
                featureName: inDevelopmentFeature
            )
            
        }
        .accentColor(AppColors.primaryFallback())
        .onAppear {
            dashboardRefreshTrigger = UUID()
            refreshAllData()
        }
        .sheet(isPresented: $showScannerSheet) {
            scannerSheet
        }
        .sheet(isPresented: $showAddMedicineForm) {
            NavigationView {
                MedicineFormView(isPresented: $showAddMedicineForm)
            }
        }
        // In ContentView or wherever you define the showFeatureInDevelopment sheet
        .sheet(isPresented: $showFeatureInDevelopment) {
            VStack(spacing: 20) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                    .padding()

                Text("Coming Soon")
                    .font(.title)
                    .fontWeight(.bold)

                Text("\(inDevelopmentFeature) feature is currently under development and will be available in a future update.")
                    .multilineTextAlignment(.center)
                    .padding()

                Button(action: {
                    // Force dismiss on the main thread
                    DispatchQueue.main.async {
                        showFeatureInDevelopment = false
                    }
                }) {
                    Text("Close")
                        .padding(.horizontal, 40)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle()) // Use plain style to avoid issues
                .padding(.top, 20)
            }
            .padding(30)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.3).edgesIgnoringSafeArea(.all))
            .onTapGesture {
                // Allow dismissal by tapping outside
                DispatchQueue.main.async {
                    showFeatureInDevelopment = false
                }
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSNotification.Name("MedicineDataChanged"))
        ) { _ in
            dashboardRefreshTrigger = UUID()
            refreshAllData()
        }
    }
}

// Persistent container for Core Data - centralized for all access
class PersistentContainer {
    static let shared = PersistentContainer()
    
    let container: NSPersistentContainer
    
    var viewContext: NSManagedObjectContext {
        return container.viewContext
    }
    
    private init() {
        container = NSPersistentContainer(name: "CoreDataModel")
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        
        // Configure view context
        viewContext.automaticallyMergesChangesFromParent = true
        viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    func saveContext() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                print("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
}
