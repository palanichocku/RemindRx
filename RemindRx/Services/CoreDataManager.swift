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
    
    func saveHistoryRecord(_ record: MedicationHistoryRecord) {
        // Check if we already have this record
        let fetchRequest: NSFetchRequest<HistoryRecordEntity> = HistoryRecordEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", record.id as CVarArg)
        
        do {
            let results = try context.fetch(fetchRequest)
            
            let entity: HistoryRecordEntity
            
            if let existingEntity = results.first {
                // Update existing
                entity = existingEntity
            } else {
                // Create new
                entity = HistoryRecordEntity(context: context)
                entity.id = record.id
            }
            
            // Set properties
            entity.medicineId = record.medicineId
            entity.medicineName = record.medicineName
            entity.scheduledTime = record.scheduledTime
            entity.recordedTime = record.recordedTime
            entity.status = record.status.rawValue
            entity.notes = record.notes
            
            // Save
            try context.save()
        } catch {
            print("Error saving history record: \(error)")
        }
    }
    
    func fetchAllHistoryRecords() -> [MedicationHistoryRecord] {
        let fetchRequest: NSFetchRequest<HistoryRecordEntity> = HistoryRecordEntity.fetchRequest()
        
        do {
            let results = try context.fetch(fetchRequest)
            
            return results.compactMap { entity -> MedicationHistoryRecord? in
                guard let id = entity.id,
                      let medicineId = entity.medicineId,
                      let medicineName = entity.medicineName,
                      let scheduledTime = entity.scheduledTime,
                      let recordedTime = entity.recordedTime,
                      let statusString = entity.status,
                      let status = MedicationDose.DoseStatus(rawValue: statusString) else {
                    return nil
                }
                
                return MedicationHistoryRecord(
                    id: id,
                    medicineId: medicineId,
                    medicineName: medicineName,
                    scheduledTime: scheduledTime,
                    recordedTime: recordedTime,
                    status: status,
                    notes: entity.notes
                )
            }
        } catch {
            print("Error fetching history records: \(error)")
            return []
        }
    }
    
    func deleteHistoryRecordsBeforeDate(_ date: Date) {
        // This should be adjusted to match your Core Data entity name if different
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "HistoryRecordEntity")
        fetchRequest.predicate = NSPredicate(format: "recordedTime < %@", date as NSDate)
        
        // Use batch delete request for efficiency with large datasets
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try context.execute(deleteRequest)
            try context.save()
            print("Successfully deleted old history records from Core Data")
        } catch {
            print("Error deleting history records: \(error)")
        }
    }
    
    // Add this to CoreDataManager
    func deleteDosesForMedicine(medicineId: UUID) {
        let fetchRequest: NSFetchRequest<DoseEntity> = DoseEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "medicineId == %@", medicineId as CVarArg)
        
        do {
            let doses = try context.fetch(fetchRequest)
            print("Found \(doses.count) dose records to delete from Core Data")
            
            for dose in doses {
                context.delete(dose)
            }
            
            try context.save()
        } catch {
            print("Error deleting doses from Core Data: \(error)")
        }
    }

    // Add this to CoreDataManager
    func deleteSchedulesForMedicine(medicineId: UUID) {
        let fetchRequest: NSFetchRequest<ScheduleEntity> = ScheduleEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "medicineId == %@", medicineId as CVarArg)
        
        do {
            let schedules = try context.fetch(fetchRequest)
            print("Found \(schedules.count) schedule records to delete from Core Data")
            
            for schedule in schedules {
                context.delete(schedule)
            }
            
            try context.save()
        } catch {
            print("Error deleting schedules from Core Data: \(error)")
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
    
    // Delete all schedules from Core Data
    func deleteAllSchedules() {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = ScheduleEntity.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try context.execute(deleteRequest)
            try context.save()
            print("Successfully deleted all schedules")
        } catch {
            print("Error deleting all schedules: \(error)")
        }
    }
    
    // Delete all doses from Core Data
    func deleteAllDoses() {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = DoseEntity.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try context.execute(deleteRequest)
            try context.save()
            print("Successfully deleted all doses")
        } catch {
            print("Error deleting all doses: \(error)")
        }
    }
    
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
        // First delete all related data
        deleteAllSchedules()
        deleteAllDoses()
        
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
    
    // MARK: - Schedule Operations
    
    func fetchAllSchedules() -> [MedicationSchedule] {
        let request: NSFetchRequest<ScheduleEntity> = ScheduleEntity.fetchRequest()
        
        do {
            let scheduleEntities = try context.fetch(request)
            return scheduleEntities.compactMap { convertToSchedule($0) }
        } catch {
            print("Error fetching schedules: \(error)")
            return []
        }
    }
    
    func saveSchedule(_ schedule: MedicationSchedule) {
        // Check if schedule already exists
        let request: NSFetchRequest<ScheduleEntity> = ScheduleEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", schedule.id as CVarArg)
        request.fetchLimit = 1
        
        do {
            let results = try context.fetch(request)
            
            let scheduleEntity: ScheduleEntity
            
            if let existingEntity = results.first {
                // Update existing entity
                scheduleEntity = existingEntity
            } else {
                // Create new entity
                scheduleEntity = ScheduleEntity(context: context)
                scheduleEntity.id = schedule.id
            }
            
            // Update entity properties
            updateScheduleEntity(scheduleEntity, with: schedule)
            
            try context.save()
        } catch {
            print("Error saving schedule: \(error)")
        }
    }
    
    func deleteSchedule(_ schedule: MedicationSchedule) {
        let request: NSFetchRequest<ScheduleEntity> = ScheduleEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", schedule.id as CVarArg)
        request.fetchLimit = 1
        
        do {
            let results = try context.fetch(request)
            
            if let scheduleEntity = results.first {
                context.delete(scheduleEntity)
                try context.save()
            }
        } catch {
            print("Error deleting schedule: \(error)")
        }
    }
    
    // MARK: - Dose Operations
    
    func fetchAllDoses() -> [MedicationDose] {
        let request: NSFetchRequest<DoseEntity> = DoseEntity.fetchRequest()
        
        do {
            let doseEntities = try context.fetch(request)
            return doseEntities.compactMap { convertToDose($0) }
        } catch {
            print("Error fetching doses: \(error)")
            return []
        }
    }
    
    func saveDose(_ dose: MedicationDose) {
        // Check if dose already exists
        let request: NSFetchRequest<DoseEntity> = DoseEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", dose.id as CVarArg)
        request.fetchLimit = 1
        
        do {
            let results = try context.fetch(request)
            
            let doseEntity: DoseEntity
            
            if let existingEntity = results.first {
                // Update existing entity
                doseEntity = existingEntity
            } else {
                // Create new entity
                doseEntity = DoseEntity(context: context)
                doseEntity.id = dose.id
            }
            
            // Update entity properties
            updateDoseEntity(doseEntity, with: dose)
            
            try context.save()
        } catch {
            print("Error saving dose: \(error)")
        }
    }
    
    func deleteDose(_ dose: MedicationDose) {
        let request: NSFetchRequest<DoseEntity> = DoseEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", dose.id as CVarArg)
        request.fetchLimit = 1
        
        do {
            let results = try context.fetch(request)
            
            if let doseEntity = results.first {
                context.delete(doseEntity)
                try context.save()
            }
        } catch {
            print("Error deleting dose: \(error)")
        }
    }
    
    // MARK: - Conversion Methods
    
    private func convertToSchedule(_ entity: ScheduleEntity) -> MedicationSchedule? {
        guard let id = entity.id,
              let medicineId = entity.medicineId,
              let medicineName = entity.medicineName,
              let frequencyString = entity.frequency,
              let frequency = MedicationSchedule.Frequency(rawValue: frequencyString),
              let startDate = entity.startDate,
              let timeOfDayData = entity.timeOfDayData else {
            return nil
        }
        
        // Decode time of day array
        var timeOfDay: [Date] = []
        if let decodedTimes = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSArray.self, from: timeOfDayData) as? [Date] {
            timeOfDay = decodedTimes
        }
        
        // Decode days of week array
        var daysOfWeek: [Int]? = nil
        if let daysData = entity.daysOfWeekData,
           let decodedDays = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSArray.self, from: daysData) as? [Int] {
            daysOfWeek = decodedDays
        }
        
        var schedule = MedicationSchedule(
            id: id,
            medicineId: medicineId,
            medicineName: medicineName,
            frequency: frequency,
            timeOfDay: timeOfDay,
            daysOfWeek: daysOfWeek,
            active: entity.active,
            startDate: startDate,
            endDate: entity.endDate,
            notes: entity.notes
        )
        
        schedule.customInterval = Int(entity.customInterval)
        
        return schedule
    }
    
    private func updateScheduleEntity(_ entity: ScheduleEntity, with schedule: MedicationSchedule) {
        entity.id = schedule.id
        entity.medicineId = schedule.medicineId
        entity.medicineName = schedule.medicineName
        entity.frequency = schedule.frequency.rawValue
        entity.active = schedule.active
        entity.startDate = schedule.startDate
        entity.endDate = schedule.endDate
        entity.notes = schedule.notes
        entity.customInterval = Int16(schedule.customInterval ?? 0)
        
        // Encode time of day array
        if let encodedTimes = try? NSKeyedArchiver.archivedData(withRootObject: schedule.timeOfDay, requiringSecureCoding: false) {
            entity.timeOfDayData = encodedTimes
        }
        
        // Encode days of week array
        if let daysOfWeek = schedule.daysOfWeek,
           let encodedDays = try? NSKeyedArchiver.archivedData(withRootObject: daysOfWeek, requiringSecureCoding: false) {
            entity.daysOfWeekData = encodedDays
        } else {
            entity.daysOfWeekData = nil
        }
    }
    
    private func convertToDose(_ entity: DoseEntity) -> MedicationDose? {
        guard let id = entity.id,
              let medicineId = entity.medicineId,
              let medicineName = entity.medicineName,
              let timestamp = entity.timestamp else {
            return nil
        }
        
        return MedicationDose(
            id: id,
            medicineId: medicineId,
            medicineName: medicineName,
            timestamp: timestamp,
            taken: entity.taken,
            notes: entity.notes,
            skippedReason: entity.skippedReason
        )
    }
    
    private func updateDoseEntity(_ entity: DoseEntity, with dose: MedicationDose) {
        entity.id = dose.id
        entity.medicineId = dose.medicineId
        entity.medicineName = dose.medicineName
        entity.timestamp = dose.timestamp
        entity.taken = dose.taken
        entity.notes = dose.notes
        entity.skippedReason = dose.skippedReason
    }

}
