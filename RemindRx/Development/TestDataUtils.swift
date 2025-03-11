import CoreData
import Foundation

class TestDataUtils {
    let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func generateTestMedicines(count: Int, completion: @escaping (Bool) -> Void) {
        // Create a private context for background operations
        let privateContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateContext.parent = context
        
        privateContext.perform {
            // Generate medicines in the private context
            for i in 0..<count {
                let medicineEntity = NSEntityDescription.insertNewObject(forEntityName: "MedicineEntity", into: privateContext) as! MedicineEntity
                
                // Set medicine properties
                medicineEntity.id = UUID()
                medicineEntity.name = "Test Medicine \(i+1)"
                medicineEntity.desc = "Description for medicine \(i+1)"
                medicineEntity.manufacturer = ["Johnson & Johnson", "Pfizer", "Novartis", "Roche", "Merck"][i % 5]
                medicineEntity.type = i % 2 == 0 ? "Prescription" : "OTC"
                medicineEntity.alertInterval = ["1 Day Before", "1 Week Before", "1 Month Before", "60 Days Before", "90 Days Before"][i % 5]
                
                // Random expiration date
                let calendar = Calendar.current
                let randomMonths = Int.random(in: 1...36)
                medicineEntity.expirationDate = calendar.date(byAdding: .month, value: randomMonths, to: Date())
                
                medicineEntity.dateAdded = Date()
                medicineEntity.barcode = String(format: "%012d", i)
                medicineEntity.source = "Test Generator"
                
                // Save every 50 items to avoid memory pressure
                if i % 50 == 0 && i > 0 {
                    do {
                        try privateContext.save()
                    } catch {
                        print("Error in batch save: \(error)")
                    }
                }
            }
            
            // Final save
            do {
                try privateContext.save()
                
                // Save to parent context on main thread
                DispatchQueue.main.async {
                    do {
                        try self.context.save()
                        completion(true)
                    } catch {
                        print("Error saving to main context: \(error)")
                        completion(false)
                    }
                }
            } catch {
                print("Error saving private context: \(error)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
    
    func deleteAllTestData(completion: @escaping (Bool) -> Void) {
        // Use batch delete request for efficiency
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "MedicineEntity")
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        batchDeleteRequest.resultType = .resultTypeObjectIDs
        
        context.perform {
            do {
                let result = try self.context.execute(batchDeleteRequest) as? NSBatchDeleteResult
                if let objectIDs = result?.result as? [NSManagedObjectID] {
                    // Merge changes to main context
                    let changes = [NSDeletedObjectsKey: objectIDs]
                    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self.context])
                }
                try self.context.save()
                
                DispatchQueue.main.async {
                    completion(true)
                }
            } catch {
                print("Error deleting all data: \(error)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
}
