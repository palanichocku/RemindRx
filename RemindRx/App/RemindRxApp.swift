import SwiftUI
import CoreData
import UserNotifications

@main
struct RemindRxApp: App {
    // Use AppDelegate for notification delegate and Core Data
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Environment state
    @StateObject private var medicineStore: MedicineStore
    
    // Initialize state objects
    init() {
        let context = PersistentContainer.shared.viewContext
        let store = MedicineStore(context: context)
        _medicineStore = StateObject(wrappedValue: store)
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
                }
        }
    }
}

// Persistent container for Core Data
class PersistentContainer {
    static let shared = PersistentContainer()
    
    let container: NSPersistentContainer
    
    var viewContext: NSManagedObjectContext {
        return container.viewContext
    }
    
    private init() {
        container = NSPersistentContainer(name: AppConstants.coreDataModelName)
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
