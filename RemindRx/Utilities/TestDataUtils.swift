//
//  TestDataUtils.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/10/25.
//
import CoreData

public class TestDataUtils {
    public let context: NSManagedObjectContext
    
    // Sample data arrays for generating random medicines
    public let medicineNames = [
        "Acetaminophen", "Ibuprofen", "Amoxicillin", "Lisinopril", "Atorvastatin",
        "Metformin", "Levothyroxine", "Amlodipine", "Metoprolol", "Omeprazole",
        "Albuterol", "Gabapentin", "Hydrochlorothiazide", "Losartan", "Simvastatin"
        // Add more names if desired
    ]
    
    public let manufacturers = [
        "Johnson & Johnson", "Pfizer", "Novartis", "Roche", "Merck",
        "AstraZeneca", "GlaxoSmithKline", "Sanofi", "AbbVie", "Bayer"
        // Add more manufacturers if desired
    ]
    
    public let descriptions = [
        "For pain relief and fever reduction",
        "Non-steroidal anti-inflammatory drug",
        "Antibiotic for bacterial infections",
        "ACE inhibitor for high blood pressure",
        "Statin medication for high cholesterol"
        // Add more descriptions if desired
    ]
    
    public init(context: NSManagedObjectContext) {
            self.context = context
    }
    
    // Create and save a Medicine entity directly
    public func saveMedicine(_ medicine: Medicine) {
        let entity = NSEntityDescription.entity(forEntityName: "MedicineEntity", in: context)!
        let medicineEntity = NSManagedObject(entity: entity, insertInto: context)
        
        medicineEntity.setValue(medicine.id, forKey: "id")
        medicineEntity.setValue(medicine.name, forKey: "name")
        medicineEntity.setValue(medicine.description, forKey: "desc")
        medicineEntity.setValue(medicine.manufacturer, forKey: "manufacturer")
        medicineEntity.setValue(medicine.type.rawValue, forKey: "type")
        medicineEntity.setValue(medicine.alertInterval.rawValue, forKey: "alertInterval")
        medicineEntity.setValue(medicine.expirationDate, forKey: "expirationDate")
        medicineEntity.setValue(Date(), forKey: "dateAdded")
        medicineEntity.setValue(medicine.barcode, forKey: "barcode")
        medicineEntity.setValue("Test Generator", forKey: "source")
        
        do {
            try context.save()
        } catch {
            print("Error saving medicine: \(error)")
        }
    }
    
    // Save directly to Core Data
    public func saveMedicineDirectly(_ medicine: Medicine) {
            let entity = NSEntityDescription.entity(forEntityName: "MedicineEntity", in: context)!
            let medicineEntity = NSManagedObject(entity: entity, insertInto: context)
            
            medicineEntity.setValue(medicine.id, forKey: "id")
            medicineEntity.setValue(medicine.name, forKey: "name")
            medicineEntity.setValue(medicine.description, forKey: "desc")
            medicineEntity.setValue(medicine.manufacturer, forKey: "manufacturer")
            medicineEntity.setValue(medicine.type.rawValue, forKey: "type")
            medicineEntity.setValue(medicine.alertInterval.rawValue, forKey: "alertInterval")
            medicineEntity.setValue(medicine.expirationDate, forKey: "expirationDate")
            medicineEntity.setValue(Date(), forKey: "dateAdded")
            medicineEntity.setValue(medicine.barcode, forKey: "barcode")
            medicineEntity.setValue("Test Generator", forKey: "source")
            
            do {
                try context.save()
            } catch {
                print("Error saving medicine: \(error)")
            }
        }
    
    
    
    // Directly delete all medicines from Core Data
    public func deleteAllTestData(completion: @escaping (Bool) -> Void) {
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "MedicineEntity")
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try context.execute(deleteRequest)
                try context.save()
                completion(true)
            } catch {
                print("Error deleting all medicines: \(error)")
                completion(false)
            }
        }
    
    public func generateTestMedicines(count: Int, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Create medicines in batches to prevent memory issues
            let batchSize = 50
            var successCount = 0
            
            for batchIndex in 0..<(count + batchSize - 1) / batchSize {
                let batchStart = batchIndex * batchSize
                let batchEnd = min(batchStart + batchSize, count)
                let batchCount = batchEnd - batchStart
                
                // Save batch directly to Core Data
                DispatchQueue.main.sync {
                    for i in 0..<batchCount {
                        self.createRandomMedicineEntity(index: batchStart + i)
                        successCount += 1
                    }
                    
                    // Save context after each batch
                    do {
                        try self.context.save()
                    } catch {
                        print("Error saving batch: \(error)")
                    }
                }
                
                // Progress update
                let progress = Double(successCount) / Double(count)
                print("Progress: \(Int(progress * 100))% - Created \(successCount) of \(count) medicines")
            }
            
            // Complete
            DispatchQueue.main.async {
                print("Test data generation complete: Created \(successCount) medicines")
                completion(true)
            }
        }
    }
    
    // Create a random medicine directly as a Core Data entity
    public func createRandomMedicineEntity(index: Int) {
        // Get random values
        let nameIndex = index % medicineNames.count
        let manufacturerIndex = index % manufacturers.count
        let descriptionIndex = index % descriptions.count
        
        // Use index to ensure uniqueness
        let name = "\(medicineNames[nameIndex]) \(index + 1)"
        
        // Create MedicineEntity directly
        let entity = NSEntityDescription.entity(forEntityName: "MedicineEntity", in: context)!
        let medicineEntity = NSManagedObject(entity: entity, insertInto: context)
        
        // Set all required attributes
        medicineEntity.setValue(UUID(), forKey: "id")
        medicineEntity.setValue(name, forKey: "name")
        medicineEntity.setValue(descriptions[descriptionIndex], forKey: "desc")
        medicineEntity.setValue(manufacturers[manufacturerIndex], forKey: "manufacturer")
        medicineEntity.setValue(Bool.random() ? "Prescription" : "OTC", forKey: "type")
        
        // Random alert interval
        let alertIntervals = ["1 Day Before", "1 Week Before", "1 Month Before", "60 Days Before", "90 Days Before"]
        medicineEntity.setValue(alertIntervals.randomElement() ?? "1 Week Before", forKey: "alertInterval")
        
        // Random expiration date
        let calendar = Calendar.current
        let today = Date()
        let randomMonths = Int.random(in: 1...36)
        let expirationDate = calendar.date(byAdding: .month, value: randomMonths, to: today) ?? today
        medicineEntity.setValue(expirationDate, forKey: "expirationDate")
        
        // Other attributes
        medicineEntity.setValue(Date(), forKey: "dateAdded")
        
        // Generate barcode
        var barcode = ""
        for _ in 0..<12 {
            barcode += String(Int.random(in: 0...9))
        }
        barcode += "0"  // Simple digit calculation
        
        medicineEntity.setValue(barcode, forKey: "barcode")
        medicineEntity.setValue("Test Generator", forKey: "source")
        
        // Save to context
        do {
            try context.save()
        } catch {
            print("Error saving entity: \(error)")
        }
    }
    
    // Generate a random EAN-13 barcode
    public func generateRandomBarcode() -> String {
        var digits = ""
        for _ in 0..<12 {
            digits += String(Int.random(in: 0...9))
        }
        
        // Simple digit calculation
        return digits + "0"
    }
    
    // Random alert interval
    public func randomAlertInterval() -> Medicine.AlertInterval {
        let intervals: [Medicine.AlertInterval] = [
            .day, .week, .month, .sixtyDays, .ninetyDays
        ]
        return intervals.randomElement() ?? .week
    }
    
    // Random expiration date between 1 and 36 months from now
    public func randomExpirationDate() -> Date {
        let calendar = Calendar.current
        let today = Date()
        let randomMonths = Int.random(in: 1...36)
        return calendar.date(byAdding: .month, value: randomMonths, to: today) ?? today
    }
}
