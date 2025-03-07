import SwiftUI
import CoreData
import Combine

public class MedicineStore: ObservableObject {
    private let coreDataManager: CoreDataManager
    private let notificationManager = NotificationManager.shared
    private let drugLookupService = DrugLookupService()
    
    @Published var medicines: [Medicine] = []
    @Published var draftMedicine: Medicine?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var lastUpdateTime: TimeInterval = Date().timeIntervalSince1970
    
    public init(context: NSManagedObjectContext) {
        self.coreDataManager = CoreDataManager(context: context)
        loadMedicines()
    }
    
    // MARK: - Data Operations
    
    func forceUIUpdate() {
        DispatchQueue.main.async {
            // Force a refresh of the medicines array
            self.loadMedicines()
            self.objectWillChange.send()
        }
    }
    
    func notifyDataChanged() {
        NotificationCenter.default.post(name: NSNotification.Name("MedicineDataChanged"), object: nil)
    }
    
    public func loadMedicines() {
        medicines = coreDataManager.fetchAllMedicines()
        // Update timestamp whenever data is loaded
        lastUpdateTime = Date().timeIntervalSince1970
    }
    
    func forceRefresh() {
        loadMedicines()
        // Explicitly notify of changes
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    public func debugMedicineInCoreData(id: UUID) {
        coreDataManager.debugMedicine(withId: id)
    }
    
    func save(_ medicine: Medicine) {
        if let existingIndex = medicines.firstIndex(where: { $0.id == medicine.id }) {
            // Update existing medicine
            medicines[existingIndex] = medicine
            print("MedicineStore: Updating existing medicine at index \(existingIndex)")
        } else {
            // Add new medicine
            medicines.append(medicine)
            print("MedicineStore: Adding new medicine")
        }
        
        // Save to Core Data
        coreDataManager.saveMedicine(medicine)
        
        // Schedule or update notification
        notificationManager.removeNotifications(for: medicine)
        notificationManager.scheduleNotification(for: medicine)
        
        // Explicitly notify subscribers that the object has changed
        DispatchQueue.main.async {
            self.loadMedicines()
            self.objectWillChange.send()
        }
        // Notify other views
        notifyDataChanged()
    }
    
    func delete(_ medicine: Medicine) {
        // First notify any AdherenceTrackingStore instances
        NotificationCenter.default.post(name: .medicineDeleted, object: medicine.id)
        
        // Then perform the original deletion
        medicines.removeAll { $0.id == medicine.id }
        coreDataManager.deleteMedicine(medicine)
        notificationManager.removeNotifications(for: medicine)
    }
    
    public func deleteAll() {
        // First notify any AdherenceTrackingStore instances
        NotificationCenter.default.post(name: .allMedicinesDeleted, object: nil)
        
        // Clear all schedules from UserDefaults
        UserDefaults.standard.removeObject(forKey: "medicationSchedules")
        
        // Clear all doses from UserDefaults
        UserDefaults.standard.removeObject(forKey: "medicationDoses")
        
        // Then perform the original deletion
        medicines.removeAll()
        
        // Delete all medicines, schedules and doses in Core Data
        coreDataManager.deleteAllMedicines()
        coreDataManager.deleteAllSchedules()
        coreDataManager.deleteAllDoses()
        
        // Remove all notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
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
}

extension Notification.Name {
    static let medicineDeleted = Notification.Name("com.remindrx.medicineDeleted")
    static let allMedicinesDeleted = Notification.Name("com.remindrx.allMedicinesDeleted")
}
