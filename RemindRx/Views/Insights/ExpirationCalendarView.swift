//
//  ExpirationCalendarView.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/11/25.
//

import SwiftUI

struct ExpirationCalendarView: View {
    @EnvironmentObject var medicineStore: MedicineStore
    @State private var selectedMonth = Date()
    
    var body: some View {
        VStack {
            // Month selector
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .padding()
                }
                
                Spacer()
                
                Text(monthFormatter.string(from: selectedMonth))
                    .font(.headline)
                
                Spacer()
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .padding()
                }
            }
            .padding(.horizontal)
            
            //Day of week header - FIX: Add index to make IDs unique
            HStack(spacing: 0) {
                ForEach(Array(daysOfWeek.enumerated()), id: \.offset) { index, day in
                    Text(day)
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 8)
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                // Leading empty spaces
                ForEach(0..<firstDayOffset, id: \.self) { index in
                    Color.clear
                        .frame(height: 40)
                        .id("empty-\(index)") // Add unique ID
                }
                
                // Days of the month
                ForEach(1...daysInMonth, id: \.self) { day in
                    CalendarDayView(
                        day: day,
                        medicines: medicinesExpiringOn(day: day, month: selectedMonth)
                    )
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
    
    // Helper methods
    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }
    
    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 1 // Sunday is 1, Monday is 2, etc.
        return calendar
    }
    
    private var daysOfWeek: [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        var days = (1...7).map { formatter.weekdaySymbols[$0 % 7] }
        // If firstWeekday is not Sunday, rotate array
        if calendar.firstWeekday > 1 {
            days.rotate(positions: calendar.firstWeekday - 1)
        }
        return days.map { String($0.prefix(1)) }
    }
    
    private var firstDayOffset: Int {
        let components = calendar.dateComponents([.year, .month], from: selectedMonth)
        guard let firstDay = calendar.date(from: components) else { return 0 }
        let weekday = calendar.component(.weekday, from: firstDay)
        return (weekday - calendar.firstWeekday + 7) % 7
    }
    
    private var daysInMonth: Int {
        let range = calendar.range(of: .day, in: .month, for: selectedMonth)!
        return range.count
    }
    
    private func previousMonth() {
        if let newDate = calendar.date(byAdding: .month, value: -1, to: selectedMonth) {
            selectedMonth = newDate
        }
    }
    
    private func nextMonth() {
        if let newDate = calendar.date(byAdding: .month, value: 1, to: selectedMonth) {
            selectedMonth = newDate
        }
    }
    
    private func medicinesExpiringOn(day: Int, month: Date) -> [Medicine] {
        let components = calendar.dateComponents([.year, .month], from: month)
        var dayComponents = DateComponents()
        dayComponents.year = components.year
        dayComponents.month = components.month
        dayComponents.day = day
        
        guard let date = calendar.date(from: dayComponents) else { return [] }
        
        // Get start and end of the day
        let startOfDay = calendar.startOfDay(for: date)
        var endComponents = calendar.dateComponents([.year, .month, .day], from: startOfDay)
        endComponents.day! += 1
        endComponents.second = -1
        let endOfDay = calendar.date(from: endComponents)!
        
        // Filter medicines expiring on this day
        return medicineStore.medicines.filter { medicine in
            let expirationDate = medicine.expirationDate
            return expirationDate >= startOfDay && expirationDate <= endOfDay
        }
    }
}

struct CalendarDayView: View {
    let day: Int
    let medicines: [Medicine]
    
    var body: some View {
        ZStack {
            // Day background
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
                .frame(height: 40)
            
            // Day number
            VStack {
                Text("\(day)")
                    .font(.footnote)
                
                if medicines.count > 0 {
                    Text("\(medicines.count)")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(dotColor))
                }
            }
        }
        .foregroundColor(textColor)
    }
    
    private var backgroundColor: Color {
        if medicines.isEmpty {
            return Color.clear
        } else {
            return Color.gray.opacity(0.1)
        }
    }
    
    private var textColor: Color {
        if medicines.isEmpty {
            return .primary
        } else {
            return .primary
        }
    }
    
    private var dotColor: Color {
        if medicines.contains(where: { $0.expirationDate < Date() }) {
            return .red
        } else {
            return .orange
        }
    }
}

// Helper extension for array rotation
extension Array {
    mutating func rotate(positions: Int) {
        let positions = positions % count
        self = Array(self[positions..<count] + self[0..<positions])
    }
}

