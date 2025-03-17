import SwiftUI
import CoreData
import UserNotifications

@main
struct RemindRxApp: App {
    // Use AppDelegate for notification delegate and Core Data
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Environment state - centralized stores that will be available throughout the app
    @StateObject private var medicineStore: MedicineStore
    @StateObject private var onboardingCoordinator = OnboardingCoordinator()
    
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
                .environmentObject(onboardingCoordinator)
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

struct ContentView: View {
    @EnvironmentObject var medicineStore: MedicineStore
    @State private var selectedTab = 0
    @State private var showScannerSheet = false
    @State private var showAddMedicineForm = false
    @State private var showOCRCamera = false
    @State private var showFeatureInDevelopment = false
    @State private var inDevelopmentFeature = ""
    @State private var showingTestDataGenerator: Bool = false
    @State private var dashboardRefreshTrigger = UUID()
    @State private var onboardingCoordinator = OnboardingCoordinator()
    

    private func refreshAllData() {
        medicineStore.loadMedicines()
    }

    var scannerSheet: some View {
        BarcodeScannerView(
            onScanCompletion: { result in
                self.showScannerSheet = false
                handleScanResult(result: result)
            },
            onCancel: {
                self.showScannerSheet = false
            }
        )
    }
    
    var ocrCameraSheet: some View {
        OCRCameraView { result in
            handleOCRResult(result)
        }
    }

    var body: some View {
        ZStack{
            TabView(selection: $selectedTab) {
                // Dashboard Tab
                NavigationView {
                    ModernDashboardView()
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
                
                // Insights Tab
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
                .environmentObject(onboardingCoordinator)
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(3)
                
            }
            .accentColor(AppColors.primaryFallback())
            // Overlay the onboarding view when needed
            if onboardingCoordinator.shouldShowOnboarding {
                OnboardingView(isShowingOnboarding: $onboardingCoordinator.shouldShowOnboarding)
                    .transition(.opacity)
                    .zIndex(100) // Ensure it's on top
            }
        }
        .onAppear {
            dashboardRefreshTrigger = UUID()
            refreshAllData()
            
            // Fix for uneven tab bar spacing - make sure the tab bar items are properly configured
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
        .sheet(isPresented: $showScannerSheet) {
            scannerSheet
        }
        .sheet(isPresented: $showAddMedicineForm) {
            NavigationView {
                MedicineFormView(isPresented: $showAddMedicineForm)
            }
        }
        .sheet(isPresented: $showOCRCamera) {
            ocrCameraSheet
        }
        .sheet(isPresented: $showFeatureInDevelopment) {
            ComingSoonFeatureView(featureName: inDevelopmentFeature)
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSNotification.Name("MedicineDataChanged"))
        ) { _ in
            dashboardRefreshTrigger = UUID()
            refreshAllData()
        }
        
    }
        
    private func handleScanResult(result: Result<String, Error>) {
        switch result {
        case .success(let barcode):
            medicineStore.lookupDrug(barcode: barcode) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let medicine):
                        // Pre-populate form with found data
                        medicineStore.draftMedicine = medicine
                        showAddMedicineForm = true
                    case .failure:
                        // Show empty form for manual entry
                        medicineStore.draftMedicine = Medicine(
                            name: "",
                            description: "",
                            manufacturer: "",
                            type: .otc,
                            alertInterval: .week,
                            expirationDate: Date().addingTimeInterval(
                                Double(60 * 60 * 24 * AppConstants.defaultExpirationDays)),
                            barcode: barcode
                        )
                        showAddMedicineForm = true
                    }
                }
            }
        case .failure:
            // Show empty form for manual entry on scan failure
            medicineStore.draftMedicine = Medicine(
                name: "",
                description: "",
                manufacturer: "",
                type: .otc,
                alertInterval: .week,
                expirationDate: Date().addingTimeInterval(
                    Double(60 * 60 * 24 * AppConstants.defaultExpirationDays))
            )
            showAddMedicineForm = true
        }
    }
    
    private func handleOCRResult(_ result: OCRResult) {
        // Create a pre-filled medicine based on OCR results
        medicineStore.draftMedicine = Medicine(
            name: result.name,
            description: result.description,
            manufacturer: result.manufacturer,
            type: result.isPrescription ? .prescription : .otc,
            alertInterval: .week, // Default alert interval
            expirationDate: result.expirationDate ?? Date().addingTimeInterval(60 * 60 * 24 * 90),
            barcode: result.barcode,
            source: "OCR Capture"
        )
        
        // Show the form for editing/confirmation
        showAddMedicineForm = true
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
