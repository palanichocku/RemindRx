import SwiftUI
import CoreData
import UserNotifications

@main
struct RemindRxApp: App {
    // Use AppDelegate for notification delegate and Core Data
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Environment state - centralized stores that will be available throughout the app
    @StateObject private var medicineStore: MedicineStore
    @StateObject private var adherenceStore: AdherenceTrackingStore
    
    // Initialize state objects
    init() {
        let context = PersistentContainer.shared.viewContext
        let medStore = MedicineStore(context: context)
        let adhStore = AdherenceTrackingStore(context: context)
        
        _medicineStore = StateObject(wrappedValue: medStore)
        _adherenceStore = StateObject(wrappedValue: adhStore)
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.managedObjectContext, PersistentContainer.shared.viewContext)
                .environmentObject(medicineStore)
                .environmentObject(adherenceStore)
                .onAppear {
                    // Request notification permissions when app launches
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                        if let error = error {
                            print("Error requesting notification permission: \(error)")
                        }
                    }
                    
                    // Initial data load
                    medicineStore.loadMedicines()
                    adherenceStore.refreshAllData()
                }
        }
    }
}

// Main TabView that manages top-level navigation
struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                DashboardView()
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(0)
            
            NavigationView {
                MedicineListView()
            }
            .tabItem {
                Label("Medicines", systemImage: "pills.fill")
            }
            .tag(1)
            
            NavigationView {
                AdherenceTrackingView()
            }
            .tabItem {
                Label("Schedule", systemImage: "calendar.badge.clock")
            }
            .tag(2)
            
            NavigationView {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(3)
        }
        .accentColor(AppColors.primaryFallback())
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
