import SwiftUI
import CoreData
import Combine

class MedicineStore: ObservableObject {
    private let coreDataManager: CoreDataManager
    private let notificationManager = NotificationManager.shared
    private let drugLookupService = DrugLookupService()
    
    @Published var medicines: [Medicine] = []
    @Published var draftMedicine: Medicine?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    init(context: NSManagedObjectContext) {
        self.coreDataManager = CoreDataManager(context: context)
        loadMedicines()
    }
    
    // MARK: - Data Operations
    
    func loadMedicines() {
        medicines = coreDataManager.fetchAllMedicines()
    }
    
    func save(_ medicine: Medicine) {
        if let existingIndex = medicines.firstIndex(where: { $0.id == medicine.id }) {
            // Update existing medicine
            medicines[existingIndex] = medicine
        } else {
            // Add new medicine
            medicines.append(medicine)
        }
        
        // Save to Core Data
        coreDataManager.saveMedicine(medicine)
        
        // Schedule or update notification
        notificationManager.removeNotifications(for: medicine)
        notificationManager.scheduleNotification(for: medicine)
    }
    
    func delete(_ medicine: Medicine) {
        // Remove from array
        medicines.removeAll { $0.id == medicine.id }
        
        // Remove from Core Data
        coreDataManager.deleteMedicine(medicine)
        
        // Cancel any notifications
        notificationManager.removeNotifications(for: medicine)
    }
    
    func deleteAll() {
        // Remove all from array
        medicines.removeAll()
        
        // Remove all from Core Data
        coreDataManager.deleteAllMedicines()
        
        // Cancel all notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    // MARK: - Barcode Operations
    
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
                        barcode: barcode
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
