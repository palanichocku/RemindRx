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
        self.coreDataManager = CoreDataManager(context: context)
        loadMedicines()
    }
    
    // MARK: - Public Methods
    
    /// Load all medicines from persistent storage
    func loadMedicines() {
        isLoading = true
        errorMessage = nil
        
        // Use background thread for potentially slow operation
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let loadedMedicines = self.coreDataManager.fetchAllMedicines()
            
            DispatchQueue.main.async {
                self.medicines = loadedMedicines
                self.isLoading = false
                self.notifyDataChanged()
            }
        }
    }
    
    /// Save a medicine to persistent storage
    func save(_ medicine: Medicine) {
        isLoading = true
        errorMessage = nil
        
        // Use background thread for potentially slow operation
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Save to Core Data
            self.coreDataManager.saveMedicine(medicine)
            
            // Schedule or update notification
            self.notificationManager.removeNotifications(for: medicine)
            self.notificationManager.scheduleNotification(for: medicine)
            
            // Update local data on main thread
            DispatchQueue.main.async {
                // If medicine already exists, update it
                if let index = self.medicines.firstIndex(where: { $0.id == medicine.id }) {
                    self.medicines[index] = medicine
                } else {
                    // Otherwise add it to the array
                    self.medicines.append(medicine)
                }
                
                self.isLoading = false
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
        NotificationCenter.default.post(name: NSNotification.Name("MedicineDataChanged"), object: nil)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let medicineDeleted = Notification.Name("com.remindrx.medicineDeleted")
    static let allMedicinesDeleted = Notification.Name("com.remindrx.allMedicinesDeleted")
    static let medicineDataChanged = Notification.Name("com.remindrx.medicineDataChanged")
}
