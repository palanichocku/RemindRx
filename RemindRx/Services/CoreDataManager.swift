import CoreData
import Foundation

public class CoreDataManager {
    public let context: NSManagedObjectContext
    
    public init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - Fetch Operations
    public func debugMedicine(withId id: UUID) {
        context.performAndWait {
            let request: NSFetchRequest<MedicineEntity> = MedicineEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            
            do {
                let results = try self.context.fetch(request)
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
    }
    
    func fetchAllMedicines() -> [Medicine] {
        var medicines: [Medicine] = []
        
        context.performAndWait {
            let request: NSFetchRequest<MedicineEntity> = MedicineEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "dateAdded", ascending: false)]
            
            do {
                let medicineEntities = try self.context.fetch(request)
                medicines = medicineEntities.map { self.convertToMedicine($0) }
            } catch {
                print("Error fetching medicines: \(error)")
            }
        }
        
        return medicines
    }
    
    func fetchMedicine(withId id: UUID) -> Medicine? {
        var medicine: Medicine? = nil
        
        context.performAndWait {
            let request: NSFetchRequest<MedicineEntity> = MedicineEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            
            do {
                let results = try self.context.fetch(request)
                medicine = results.first.map { self.convertToMedicine($0) }
            } catch {
                print("Error fetching medicine: \(error)")
            }
        }
        
        return medicine
    }
    
    func fetchExpiredMedicines() -> [Medicine] {
        var medicines: [Medicine] = []
        
        context.performAndWait {
            let request: NSFetchRequest<MedicineEntity> = MedicineEntity.fetchRequest()
            request.predicate = NSPredicate(format: "expirationDate < %@", Date() as NSDate)
            request.sortDescriptors = [NSSortDescriptor(key: "expirationDate", ascending: true)]
            
            do {
                let medicineEntities = try self.context.fetch(request)
                medicines = medicineEntities.map { self.convertToMedicine($0) }
            } catch {
                print("Error fetching expired medicines: \(error)")
            }
        }
        
        return medicines
    }
    
    // MARK: - Save Operations
    
    func saveMedicine(_ medicine: Medicine) {
        context.performAndWait {
            let request: NSFetchRequest<MedicineEntity> = MedicineEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", medicine.id as CVarArg)
            
            do {
                let results = try self.context.fetch(request)
                
                if let existingEntity = results.first {
                    
                    // Explicitly print the type being saved
                    print("CoreDataManager: Updating medicine with type: \(medicine.type.rawValue)")
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
                    try self.context.save()
                    print("CoreDataManager: Entity saved successfully")
                    
                    // Verify the save
                    //if let savedDate = existingEntity.expirationDate {
                    //    print("CoreDataManager: Verified expiration date after save: \(savedDate)")
                    //}
                } else {
                    // Create new entity
                    print("CoreDataManager: Creating new entity with type: \(medicine.type.rawValue)")
                    let medicineEntity = MedicineEntity(context: self.context)
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
                    
                    try self.context.save()
                }
            } catch {
                print("CoreDataManager: Error saving medicine: \(error)")
            }
        }
    }
    
    // MARK: - Delete Operations
    
    func deleteMedicine(_ medicine: Medicine) {
        context.performAndWait {
            let request: NSFetchRequest<MedicineEntity> = MedicineEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", medicine.id as CVarArg)
            request.fetchLimit = 1
            
            do {
                let results = try self.context.fetch(request)
                
                if let medicineEntity = results.first {
                    self.context.delete(medicineEntity)
                    try self.context.save()
                }
            } catch {
                print("Error deleting medicine: \(error)")
            }
        }
    }
    
    // Enhanced version of deleteAllMedicines that ensures all related data is deleted
    func deleteAllMedicines() {
        context.performAndWait {
            // First delete all related data
            
            // Then delete the medicines using a batch delete
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = MedicineEntity.fetchRequest()
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            deleteRequest.resultType = .resultTypeObjectIDs
            
            do {
                let result = try self.context.execute(deleteRequest) as? NSBatchDeleteResult
                if let objectIDs = result?.result as? [NSManagedObjectID] {
                    // Merge the changes into our context
                    let changes = [NSDeletedObjectsKey: objectIDs]
                    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self.context])
                }
                
                try self.context.save()
                print("Successfully deleted all medicines")
            } catch {
                print("Error deleting all medicines: \(error)")
            }
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
    
    // MARK: - Notification Related
    
    func fetchMedicinesNeedingAlerts() -> [Medicine] {
        var medicines: [Medicine] = []
        
        context.performAndWait {
            let now = Date()
            let calendar = Calendar.current
            
            // Fetch all non-expired medicines
            let request: NSFetchRequest<MedicineEntity> = MedicineEntity.fetchRequest()
            request.predicate = NSPredicate(format: "expirationDate > %@", now as NSDate)
            
            do {
                let medicineEntities = try self.context.fetch(request)
                
                // Filter medicines that need alerts based on their alert intervals
                medicines = medicineEntities.compactMap { entity -> Medicine? in
                    guard let expirationDate = entity.expirationDate,
                          let alertInterval = entity.alertInterval,
                          let alertIntervalEnum = Medicine.AlertInterval(rawValue: alertInterval) else {
                        return nil
                    }
                    
                    let medicine = self.convertToMedicine(entity)
                    
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
            }
        }
        
        return medicines
    }
}
