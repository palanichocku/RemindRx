//
//  MedicationHistoryRecord.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/10/25.
//

// Add this new model for history records
import Foundation
import CoreData

struct MedicationHistoryRecord: Identifiable, Codable {
    var id: UUID
    var medicineId: UUID
    var medicineName: String
    var scheduledTime: Date
    var recordedTime: Date
    var status: MedicationDose.DoseStatus
    var notes: String?
    
    init(id: UUID = UUID(),
         medicineId: UUID,
         medicineName: String,
         scheduledTime: Date,
         recordedTime: Date,
         status: MedicationDose.DoseStatus,
         notes: String? = nil) {
        self.id = id
        self.medicineId = medicineId
        self.medicineName = medicineName
        self.scheduledTime = scheduledTime
        self.recordedTime = recordedTime
        self.status = status
        self.notes = notes
    }
}

// Add this to your Core Data entities
// HistoryRecordEntity+CoreDataClass.swift
import Foundation
import CoreData

public class HistoryRecordEntity: NSManagedObject {
}

// HistoryRecordEntity+CoreDataProperties.swift
import Foundation
import CoreData

extension HistoryRecordEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<HistoryRecordEntity> {
        return NSFetchRequest<HistoryRecordEntity>(entityName: "HistoryRecordEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var medicineId: UUID?
    @NSManaged public var medicineName: String?
    @NSManaged public var scheduledTime: Date?
    @NSManaged public var recordedTime: Date?
    @NSManaged public var status: String?
    @NSManaged public var notes: String?
}

// Don't forget to add the HistoryRecordEntity to your Core Data model!
