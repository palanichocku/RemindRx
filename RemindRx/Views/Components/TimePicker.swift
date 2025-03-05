//
//  TimePicker.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/4/25.
//

import SwiftUI

struct TimePicker: View {
    @Binding var selectedTimes: [Date]
    let count: Int
    
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
    }
    
    private func timeLabel(_ index: Int) -> String {
        switch index {
        case 0: return "Morning"
        case 1: return "Afternoon"
        case 2: return "Evening"
        default: return "Time \(index + 1)"
        }
    }
    
    private func timeBinding(_ index: Int) -> Binding<Date> {
        // Ensure we have enough dates in the array
        while selectedTimes.count <= index {
            // Add default times
            let hour = 8 + (index * 8) // 8am, 4pm, 10pm
            let defaultTime = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
            selectedTimes.append(defaultTime)
        }
        
        return Binding(
            get: { selectedTimes[index] },
            set: { selectedTimes[index] = $0 }
        )
    }
    
}
