//
//  TimePickerView.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/5/25.
//

import SwiftUI

// Improved TimePickerView with more consistent behavior
struct TimePickerView: View {
    @Binding var selectedTimes: [Date]
    let count: Int
    
    // Labels for different time slots
    let timeLabels = ["Morning", "Afternoon", "Evening", "Bedtime"]
    
    // Default hours for each time slot
    let defaultHours = [9, 13, 18, 21]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            ForEach(0..<count, id: \.self) { index in
                HStack {
                    Text(timeLabel(index))
                        .font(.subheadline)
                    
                    Spacer()
                    
                    DatePicker(
                        "",
                        selection: timeBinding(index),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                }
            }
        }
        .onAppear {
            // Ensure we have exactly the right number of times
            ensureCorrectTimeCount()
        }
    }
    
    private func ensureCorrectTimeCount() {
        // Add default times if needed
        while selectedTimes.count < count {
            let index = selectedTimes.count
            let hour = index < defaultHours.count ? defaultHours[index] : 9
            let defaultTime = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
            selectedTimes.append(defaultTime)
        }
        
        // Remove extra times if needed
        if selectedTimes.count > count {
            selectedTimes = Array(selectedTimes.prefix(count))
        }
    }
    
    private func timeLabel(_ index: Int) -> String {
        return index < timeLabels.count ? timeLabels[index] : "Time \(index + 1)"
    }
    
    private func timeBinding(_ index: Int) -> Binding<Date> {
        // Ensure we have enough dates in the array
        ensureCorrectTimeCount()
        
        return Binding(
            get: { selectedTimes[index] },
            set: { selectedTimes[index] = $0 }
        )
    }
}
