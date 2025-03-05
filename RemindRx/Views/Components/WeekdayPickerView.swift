//
//  WeekdayPickerView.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/5/25.
//

import SwiftUI

// Improved WeekdayPickerView with more robust handling
struct WeekdayPickerView: View {
    @Binding var selectedDays: [Int]
    let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Days of Week")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                ForEach(0..<7) { index in
                    WeekdayButtonView(
                        day: weekdays[index],
                        isSelected: isSelected(day: index + 1),
                        action: {
                            toggleDay(index + 1)
                        }
                    )
                }
            }
        }
        .padding(.vertical, 5)
        .onAppear {
            // Ensure at least one day is selected
            if selectedDays.isEmpty {
                DispatchQueue.main.async {
                    selectedDays = [1] // Default to Monday
                }
            }
            
            // Remove any invalid day values
            selectedDays = selectedDays.filter { $0 >= 1 && $0 <= 7 }
            
            // Sort days for consistency
            selectedDays.sort()
        }
    }
    
    // More reliable selection check
    private func isSelected(day: Int) -> Bool {
        return selectedDays.contains(day)
    }
    
    private func toggleDay(_ day: Int) {
        if selectedDays.contains(day) {
            // Only remove if there will still be at least one day selected
            if selectedDays.count > 1 {
                selectedDays.removeAll { $0 == day }
            }
        } else {
            selectedDays.append(day)
            selectedDays.sort()
        }
    }
}
