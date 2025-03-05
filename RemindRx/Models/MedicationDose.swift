//
//  MedicationDose.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/4/25.
//

import Foundation

struct MedicationDose: Identifiable, Codable {
    var id = UUID()
    var medicineId: UUID
    var medicineName: String
    var timestamp: Date
    var taken: Bool
    var notes: String?
    var skippedReason: String?
    
    // Status for the dose
    enum DoseStatus: String, Codable {
        case taken = "Taken"
        case missed = "Missed"
        case skipped = "Skipped"
    }
    
    var status: DoseStatus {
        if taken {
            return .taken
        } else if skippedReason != nil {
            return .skipped
        } else {
            return .missed
        }
    }
    
    // Function to create a dose record for a medicine
    static func create(for medicine: Medicine, taken: Bool = true, notes: String? = nil, skippedReason: String? = nil) -> MedicationDose {
        return MedicationDose(
            medicineId: medicine.id,
            medicineName: medicine.name,
            timestamp: Date(),
            taken: taken,
            notes: notes,
            skippedReason: skippedReason
        )
    }
}

