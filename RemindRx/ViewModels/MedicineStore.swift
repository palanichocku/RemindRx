import SwiftUI
import CoreData
import Combine

/// Central store for managing medicines in the app
class MedicineStore: ObservableObject {
    // MARK: - Published Properties
    
    /// Array of all medicines
    @Published private(set) var medicines: [Medicine] = []
    
    /// Medicine being edited or created
    @Published var draftMedicine: Medicine?
    
    /// Loading state
    @Published private(set) var isLoading: Bool = false
    
    /// Error message if something goes wrong
    @Published private(set) var errorMessage: String?
    
    /// Filter for expired medicines only
    @Published var showExpiredOnly: Bool = false
    
    // MARK: - Dependencies
    
    private let coreDataManager: CoreDataManager
    private let notificationManager = NotificationManager.shared
    private let drugLookupService = DrugLookupService()
    
    // MARK: - Computed Properties
    
    /// Filtered list of medicines based on current filter settings
    var filteredMedicines: [Medicine] {
        if showExpiredOnly {
            return medicines.filter { $0.expirationDate < Date() }
        } else {
            return medicines
        }
    }
    
    /// Medicines that will expire soon (within their alert interval)
    var expiringSoonMedicines: [Medicine] {
        return medicines.filter { medicine in
            let timeInterval = medicine.expirationDate.timeIntervalSince(Date())
            return timeInterval > 0 && timeInterval < Double(medicine.alertInterval.days * 24 * 60 * 60)
        }
    }
    
    /// Medicines that have already expired
    var expiredMedicines: [Medicine] {
        return medicines.filter { $0.expirationDate < Date() }
    }
    
    // MARK: - Initialization
    
    init(context: NSManagedObjectContext) {
        //self.context = context
        self.coreDataManager = CoreDataManager(context: context)
        loadMedicines()
        // Get the shared AdherenceTrackingStore and set up listeners
        //let adherenceStore = AdherenceTrackingStore(context: context)
        //adherenceStore.setupNotificationListeners()
    }
    
    // MARK: - Public Methods
    
    func deleteMedicineWithCleanup(_ medicine: Medicine) {
        print("🧹 Deleting medicine with ID \(medicine.id) and cleaning up related data")
        
        // First notify the AdherenceTrackingStore to clean up related schedules and doses
        NotificationCenter.default.post(
            name: NSNotification.Name("MedicineDeletedCleanup"),
            object: nil,
            userInfo: ["medicineId": medicine.id]
        )
        
        // Then delete the medicine itself using standard Core Data approach
        let managedObjectContext = PersistentContainer.shared.viewContext
        
        // Find the medicine entity with this ID
        let fetchRequest: NSFetchRequest<MedicineEntity> = MedicineEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", medicine.id as CVarArg)
        
        do {
            let results = try managedObjectContext.fetch(fetchRequest)
            
            if let entityToDelete = results.first {
                // Delete the entity
                managedObjectContext.delete(entityToDelete)
                
                // Save changes
                try managedObjectContext.save()
                print("Successfully deleted medicine entity from Core Data")
            } else {
                print("Warning: Could not find medicine entity with ID \(medicine.id)")
            }
        } catch {
            print("Error deleting medicine: \(error)")
        }
        
        // Reload medicines after deletion
        loadMedicines()
        
        // Notify that medicine data has changed
        NotificationCenter.default.post(name: NSNotification.Name("MedicineDataChanged"), object: nil)
    }

    // Add this method to handle all medicines deletion with cleanup
    func deleteAllMedicinesWithCleanup() {
        print("🧹 Deleting ALL medicines and cleaning up related data")
        
        // First notify the AdherenceTrackingStore to clean up all schedules and doses
        NotificationCenter.default.post(name: NSNotification.Name("AllMedicinesDeletedCleanup"), object: nil)
        
        // Delete all medicines from Core Data
        let managedObjectContext = PersistentContainer.shared.viewContext
        let fetchRequest: NSFetchRequest<MedicineEntity> = MedicineEntity.fetchRequest()
        
        do {
            let entities = try managedObjectContext.fetch(fetchRequest)
            for entity in entities {
                managedObjectContext.delete(entity)
            }
            try managedObjectContext.save()
            print("Successfully deleted all medicines from Core Data")
        } catch {
            print("Error deleting all medicines: \(error)")
        }
        
        // Reload medicines after deletion
        loadMedicines()
        
        // Notify that medicine data has changed
        NotificationCenter.default.post(name: NSNotification.Name("MedicineDataChanged"), object: nil)
    }
    
    /// Load all medicines from persistent storage
    func loadMedicines() {
        
        
        
        // Only set isLoading to true if we don't already have medicines loaded
        // This avoids the loading screen when refreshing data if we already have items
        let shouldShowLoading = medicines.isEmpty
        
        if shouldShowLoading {
            // Set loading state on main thread
            DispatchQueue.main.async {
                self.isLoading = true
                self.errorMessage = nil
            }
        }

        // Use background thread for potentially slow operation
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let loadedMedicines = self.coreDataManager.fetchAllMedicines()
            
            DispatchQueue.main.async {
                self.medicines = loadedMedicines
                // Short delay before hiding loading to avoid flicker
                if self.isLoading {
                    // Add a tiny delay to avoid visual flicker
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.isLoading = false
                    }
                }
                self.notifyDataChanged()
            }
        }
    }
    
    /// Save a medicine to persistent storage
    // In MedicineStore.swift - update the save method
    func save(_ medicine: Medicine) {
        // Set loading state on main thread
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        // Create a copy of the data for background work
        let medicineCopy = medicine
        
        // Use background thread for Core Data operations
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Save to Core Data
            self.coreDataManager.saveMedicine(medicineCopy)
            
            // Schedule notification
            self.notificationManager.removeNotifications(for: medicineCopy)
            self.notificationManager.scheduleNotification(for: medicineCopy)
            
            // Update UI on main thread
            DispatchQueue.main.async {
                // Update local array
                if let index = self.medicines.firstIndex(where: { $0.id == medicineCopy.id }) {
                    self.medicines[index] = medicineCopy
                } else {
                    self.medicines.append(medicineCopy)
                }
                
                // Reset loading state
                self.isLoading = false
                
                // Notify observers
                self.notifyDataChanged()
            }
        }
    }
    
    /// Delete a medicine from persistent storage
    func delete(_ medicine: Medicine) {
        isLoading = true
        errorMessage = nil
        
        // Use background thread for potentially slow operation
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Notify other components about the deletion
            NotificationCenter.default.post(name: .medicineDeleted, object: medicine.id)
            
            // Delete from Core Data
            self.coreDataManager.deleteMedicine(medicine)
            
            // Remove notifications
            self.notificationManager.removeNotifications(for: medicine)
            
            // Update local data on main thread
            DispatchQueue.main.async {
                self.medicines.removeAll { $0.id == medicine.id }
                self.isLoading = false
                self.notifyDataChanged()
            }
        }
    }
    
    /// Delete all medicines
    func deleteAll() {
        isLoading = true
        errorMessage = nil
        
        // Use background thread for potentially slow operation
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Notify other components about the deletion
            NotificationCenter.default.post(name: .allMedicinesDeleted, object: nil)
            
            // Delete all medicines from Core Data
            self.coreDataManager.deleteAllMedicines()
            
            // Remove all notifications
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            
            // Update local data on main thread
            DispatchQueue.main.async {
                self.medicines.removeAll()
                self.isLoading = false
                self.notifyDataChanged()
            }
        }
    }
    
    /// Look up medicine information by barcode
    func lookupDrug(barcode: String, completion: @escaping (Result<Medicine, Error>) -> Void) {
        isLoading = true
        errorMessage = nil
        
        drugLookupService.lookupDrugByBarcode(barcode: barcode) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let drugInfo):
                    // Create medicine object from drug info
                    let medicine = Medicine(
                        name: drugInfo.name,
                        description: drugInfo.description,
                        manufacturer: drugInfo.manufacturer,
                        type: drugInfo.isPrescription ? .prescription : .otc,
                        alertInterval: .week, // Default alert interval
                        expirationDate: Date().addingTimeInterval(60*60*24*365), // Default to 1 year from now
                        barcode: barcode,
                        source: drugInfo.source
                    )
                    completion(.success(medicine))
                    
                case .failure(let error):
                    self?.errorMessage = "Could not find drug information: \(error.localizedDescription)"
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Get medicine by ID - safely returns nil if not found
    func getMedicine(byId id: UUID) -> Medicine? {
        return medicines.first(where: { $0.id == id })
    }
    
    // MARK: - Private Methods
    
    /// Notify observers that medicine data has changed
    private func notifyDataChanged() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("MedicineDataChanged"), object: nil)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let medicineDeleted = Notification.Name("com.remindrx.medicineDeleted")
    static let allMedicinesDeleted = Notification.Name("com.remindrx.allMedicinesDeleted")
    static let medicineDataChanged = Notification.Name("com.remindrx.medicineDataChanged")
}
