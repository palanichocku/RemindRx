import CoreData
import Foundation

class CoreDataManager {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - Fetch Operations
    
    func fetchAllMedicines() -> [Medicine] {
        let request: NSFetchRequest<MedicineEntity> = MedicineEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "dateAdded", ascending: false)]
        
        do {
            let medicineEntities = try context.fetch(request)
            return medicineEntities.map { convertToMedicine($0) }
        } catch {
            print("Error fetching medicines: \(error)")
            return []
        }
    }
    
    func fetchMedicine(withId id: UUID) -> Medicine? {
        let request: NSFetchRequest<MedicineEntity> = MedicineEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        do {
            let results = try context.fetch(request)
            return results.first.map { convertToMedicine($0) }
        } catch {
            print("Error fetching medicine: \(error)")
            return nil
        }
    }
    
    func fetchExpiredMedicines() -> [Medicine] {
        let request: NSFetchRequest<MedicineEntity> = MedicineEntity.fetchRequest()
        request.predicate = NSPredicate(format: "expirationDate < %@", Date() as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "expirationDate", ascending: true)]
        
        do {
            let medicineEntities = try context.fetch(request)
            return medicineEntities.map { convertToMedicine($0) }
        } catch {
            print("Error fetching expired medicines: \(error)")
            return []
        }
    }
    
    // MARK: - Save Operations
    
    func saveMedicine(_ medicine: Medicine) {
        // Check if medicine already exists
        let request: NSFetchRequest<MedicineEntity> = MedicineEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", medicine.id as CVarArg)
        request.fetchLimit = 1
        
        do {
            let results = try context.fetch(request)
            
            let medicineEntity: MedicineEntity
            
            if let existingEntity = results.first {
                // Update existing entity
                medicineEntity = existingEntity
            } else {
                // Create new entity
                medicineEntity = MedicineEntity(context: context)
                medicineEntity.id = medicine.id
                medicineEntity.dateAdded = medicine.dateAdded
            }
            
            // Update entity properties
            updateMedicineEntity(medicineEntity, with: medicine)
            
            try context.save()
        } catch {
            print("Error saving medicine: \(error)")
        }
    }
    
    // MARK: - Delete Operations
    
    func deleteMedicine(_ medicine: Medicine) {
        let request: NSFetchRequest<MedicineEntity> = MedicineEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", medicine.id as CVarArg)
        request.fetchLimit = 1
        
        do {
            let results = try context.fetch(request)
            
            if let medicineEntity = results.first {
                context.delete(medicineEntity)
                try context.save()
            }
        } catch {
            print("Error deleting medicine: \(error)")
        }
    }
    
    func deleteAllMedicines() {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = MedicineEntity.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try context.execute(deleteRequest)
            try context.save()
        } catch {
            print("Error deleting all medicines: \(error)")
        }
    }
    
    // MARK: - Conversion Methods
    
    private func convertToMedicine(_ entity: MedicineEntity) -> Medicine {
        return Medicine(
            id: entity.id ?? UUID(),
            name: entity.name ?? "",
            description: entity.desc ?? "",
            manufacturer: entity.manufacturer ?? "",
            type: Medicine.MedicineType(rawValue: entity.type ?? "OTC") ?? .otc,
            alertInterval: Medicine.AlertInterval(rawValue: entity.alertInterval ?? "week") ?? .week,
            expirationDate: entity.expirationDate ?? Date(),
            dateAdded: entity.dateAdded ?? Date(),
            barcode: entity.barcode
        )
    }
    
    private func updateMedicineEntity(_ entity: MedicineEntity, with medicine: Medicine) {
        entity.name = medicine.name
        entity.desc = medicine.description
        entity.manufacturer = medicine.manufacturer
        entity.type = medicine.type.rawValue
        entity.alertInterval = medicine.alertInterval.rawValue
        entity.expirationDate = medicine.expirationDate
        entity.barcode = medicine.barcode
    }
    
    // MARK: - Notification Related
    
    func fetchMedicinesNeedingAlerts() -> [Medicine] {
        let now = Date()
        let calendar = Calendar.current
        
        // Fetch all non-expired medicines
        let request: NSFetchRequest<MedicineEntity> = MedicineEntity.fetchRequest()
        request.predicate = NSPredicate(format: "expirationDate > %@", now as NSDate)
        
        do {
            let medicineEntities = try context.fetch(request)
            
            // Filter medicines that need alerts based on their alert intervals
            return medicineEntities.compactMap { entity -> Medicine? in
                guard let expirationDate = entity.expirationDate,
                      let alertInterval = entity.alertInterval,
                      let alertIntervalEnum = Medicine.AlertInterval(rawValue: alertInterval) else {
                    return nil
                }
                
                let medicine = convertToMedicine(entity)
                
                // Calculate the alert date based on alert interval
                let alertDate = calendar.date(byAdding: .day, value: -alertIntervalEnum.days, to: expirationDate)
                
                // Check if the alert date is today or in the past (but medicine not expired)
                if let alertDate = alertDate, alertDate <= now && expirationDate > now {
                    return medicine
                }
                
                return nil
            }
        } catch {
            print("Error fetching medicines needing alerts: \(error)")
            return []
        }
    }
}
