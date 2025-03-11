//
//  TestDataGenerator.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/11/25.
//

import SwiftUI
import CoreData

class TestDataGenerator {
    let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func generateTestData(count: Int, completion: @escaping (Bool) -> Void) {
        // Create a background context
        let backgroundContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        backgroundContext.parent = context
        
        backgroundContext.perform {
            // Generate test data in batches
            let batchSize = 20
            var success = true
            
            for i in 0..<count {
                // Create a new medicine entity
                let entity = NSEntityDescription.insertNewObject(forEntityName: "MedicineEntity", into: backgroundContext) as! MedicineEntity
                
                // Set medicine properties
                entity.id = UUID()
                entity.name = "Test Medicine \(i+1)"
                entity.desc = "Description for test medicine \(i+1)"
                entity.manufacturer = ["Johnson & Johnson", "Pfizer", "Novartis", "Roche", "Merck"][i % 5]
                entity.type = i % 2 == 0 ? "Prescription" : "OTC"
                entity.alertInterval = ["1 Day Before", "1 Week Before", "1 Month Before", "60 Days Before", "90 Days Before"][i % 5]
                
                // Random expiration date
                let calendar = Calendar.current
                let randomMonths = Int.random(in: 1...36)
                entity.expirationDate = calendar.date(byAdding: .month, value: randomMonths, to: Date())
                
                entity.dateAdded = Date()
                entity.barcode = String(format: "%012d", i)
                entity.source = "Test Generator"
                
                // Save batch periodically to avoid memory pressure
                if i % batchSize == 0 && i > 0 {
                    do {
                        try backgroundContext.save()
                    } catch {
                        print("Error saving batch: \(error)")
                        success = false
                    }
                }
            }
            
            // Final save
            do {
                try backgroundContext.save()
                
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
                print("Error in final save: \(error)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
    
    func deleteAllData(completion: @escaping (Bool) -> Void) {
        let backgroundContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        backgroundContext.parent = context
        
        backgroundContext.perform {
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "MedicineEntity")
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            batchDeleteRequest.resultType = .resultTypeObjectIDs
            
            do {
                let result = try backgroundContext.execute(batchDeleteRequest) as? NSBatchDeleteResult
                
                if let objectIDs = result?.result as? [NSManagedObjectID] {
                    // Merge changes to our view context
                    let changes = [NSDeletedObjectsKey: objectIDs]
                    
                    DispatchQueue.main.async {
                        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self.context])
                        
                        do {
                            try self.context.save()
                            completion(true)
                        } catch {
                            print("Error saving context after delete: \(error)")
                            completion(false)
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(false)
                    }
                }
            } catch {
                print("Error executing batch delete: \(error)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
}
