//
//  WeekdayPicker.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/5/25.
//

import SwiftUI

// Helper for weekday picking
struct WeekdayPicker: View {
    @Binding var selectedDays: [Int]
    let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Days of Week")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                ForEach(0..<7) { index in
                    WeekdayButton(
                        day: weekdays[index],
                        isSelected: selectedDays.contains(index + 1),
                        action: {
                            toggleDay(index + 1)
                        }
                    )
                }
            }
        }
        .padding(.vertical, 5)
    }
    
    private func toggleDay(_ day: Int) {
        if selectedDays.contains(day) {
            selectedDays.removeAll { $0 == day }
        } else {
            selectedDays.append(day)
            selectedDays.sort()
        }
    }
    
}
