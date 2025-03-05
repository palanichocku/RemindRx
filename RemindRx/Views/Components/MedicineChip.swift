//
//  MedicineChip.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/5/25.
//
import SwiftUI

// Medicine selection chip
struct MedicineChip: View {
    let medicine: Medicine
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(medicine.name)
                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(isSelected ? AppColors.primaryFallback() : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}
