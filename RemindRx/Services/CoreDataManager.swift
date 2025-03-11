import CoreData
import Foundation

public class CoreDataManager {
    public let context: NSManagedObjectContext
    
    public init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - Fetch Operations
    public func debugMedicine(withId id: UUID) {
        let request: NSFetchRequest<MedicineEntity> = MedicineEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let results = try context.fetch(request)
            if let entity = results.first {
                let expirationDate = entity.expirationDate
                print("CoreDataManager: DIRECT FROM CORE DATA - Medicine ID: \(id)")
                print("CoreDataManager: Expiration date in Core Data: \(expirationDate?.description ?? "nil")")
            } else {
                print("CoreDataManager: No entity found with ID: \(id)")
            }
        } catch {
            print("CoreDataManager: Error fetching medicine: \(error)")
        }
    }
    
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
        // Try a more direct approach
       let request: NSFetchRequest<MedicineEntity> = MedicineEntity.fetchRequest()
       request.predicate = NSPredicate(format: "id == %@", medicine.id as CVarArg)
       
       do {
           let results = try context.fetch(request)
           
           if let existingEntity = results.first {
               // Explicitly set each attribute
               print("CoreDataManager: Updating entity directly - ID: \(medicine.id)")
               print("CoreDataManager: New expiration date: \(medicine.expirationDate)")
               
               existingEntity.setValue(medicine.name, forKey: "name")
               existingEntity.setValue(medicine.description, forKey: "desc")
               existingEntity.setValue(medicine.manufacturer, forKey: "manufacturer")
               existingEntity.setValue(medicine.type.rawValue, forKey: "type")
               existingEntity.setValue(medicine.alertInterval.rawValue, forKey: "alertInterval")
               existingEntity.setValue(medicine.expirationDate, forKey: "expirationDate")
               existingEntity.setValue(medicine.barcode, forKey: "barcode")
               existingEntity.setValue(medicine.source, forKey: "source")
               
               // Save immediately
               try context.save()
               print("CoreDataManager: Entity saved successfully")
               
               // Verify the save
               if let savedDate = existingEntity.expirationDate {
                   print("CoreDataManager: Verified expiration date after save: \(savedDate)")
               }
           } else {
               // Create new entity
               print("CoreDataManager: Creating new entity - ID: \(medicine.id)")
               let medicineEntity = MedicineEntity(context: context)
               medicineEntity.id = medicine.id
               medicineEntity.name = medicine.name
               medicineEntity.desc = medicine.description
               medicineEntity.manufacturer = medicine.manufacturer
               medicineEntity.type = medicine.type.rawValue
               medicineEntity.alertInterval = medicine.alertInterval.rawValue
               medicineEntity.expirationDate = medicine.expirationDate
               medicineEntity.dateAdded = medicine.dateAdded
               medicineEntity.barcode = medicine.barcode
               medicineEntity.source = medicine.source
               
               try context.save()
           }
       } catch {
           print("CoreDataManager: Error saving medicine: \(error)")
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
    
    // Enhanced version of deleteAllMedicines that ensures all related data is deleted
    func deleteAllMedicines() {
        // First delete all related date
        
        // Then delete the medicines
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = MedicineEntity.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try context.execute(deleteRequest)
            try context.save()
            print("Successfully deleted all medicines")
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
            barcode: entity.barcode,
            source: entity.source
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
        entity.source = medicine.source // Add source
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
