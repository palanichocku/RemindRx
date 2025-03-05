//
//  WeekdayButton.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/5/25.
//
import SwiftUI

struct WeekdayButton: View {
    let day: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(day.prefix(1))
                .font(.system(size: 14, weight: .medium))
                .frame(width: 30, height: 30)
                .background(isSelected ? AppColors.primaryFallback() : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Circle())
        }
    }
}
