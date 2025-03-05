//
//  MedicationSchedule.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/5/25.
//

import SwiftUI


struct MedicationSchedule: Identifiable, Codable {
    var id = UUID()
    var medicineId: UUID
    var medicineName: String
    
    enum Frequency: String, Codable, CaseIterable {
        case daily = "Daily"
        case twiceDaily = "Twice Daily"
        case threeTimesDaily = "Three Times Daily"
        case weekly = "Weekly"
        case asNeeded = "As Needed"
        case custom = "Custom"
    }
    
    var frequency: Frequency
    var timeOfDay: [Date] // Store times for doses
    var daysOfWeek: [Int]? // For weekly: 1 = Monday, 7 = Sunday
    var active: Bool = true
    var startDate: Date
    var endDate: Date?
    var notes: String?
    
    // For custom schedules
    var customInterval: Int? // Days between doses
    
    // Create a default schedule for a medicine
    static func createDefault(for medicine: Medicine) -> MedicationSchedule {
        // Default to daily at 9:00 AM
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 9
        components.minute = 0
        
        let morningTime = calendar.date(from: components) ?? Date()
        
        return MedicationSchedule(
            medicineId: medicine.id,
            medicineName: medicine.name,
            frequency: .daily,
            timeOfDay: [morningTime],
            daysOfWeek: nil,
            active: true,
            startDate: Date()
        )
    }
    
    // Get next scheduled dose time
    func getTodayDoseTimes() -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var doseTimes: [Date] = []
        
        // Check if schedule is in date range
        if today < startDate {
            print("Schedule for \(medicineName) hasn't started yet")
            return []
        }
        
        if let endDate = endDate, today > endDate {
            print("Schedule for \(medicineName) has ended")
            return []
        }
        
        switch frequency {
        case .daily, .twiceDaily, .threeTimesDaily:
            // Add all times for today
            for time in timeOfDay {
                let components = calendar.dateComponents([.hour, .minute], from: time)
                var doseComponents = calendar.dateComponents([.year, .month, .day], from: today)
                doseComponents.hour = components.hour
                doseComponents.minute = components.minute
                
                if let doseTime = calendar.date(from: doseComponents) {
                    doseTimes.append(doseTime)
                }
            }
            
        case .weekly:
            // Check if today is a scheduled day
            let currentWeekday = calendar.component(.weekday, from: today)
            // Convert from Sunday=1 to Monday=1 if needed
            let adjustedWeekday = currentWeekday % 7 + 1
            
            if let daysOfWeek = daysOfWeek, daysOfWeek.contains(adjustedWeekday) {
                // Today is a scheduled day, add all times
                for time in timeOfDay {
                    let components = calendar.dateComponents([.hour, .minute], from: time)
                    var doseComponents = calendar.dateComponents([.year, .month, .day], from: today)
                    doseComponents.hour = components.hour
                    doseComponents.minute = components.minute
                    
                    if let doseTime = calendar.date(from: doseComponents) {
                        doseTimes.append(doseTime)
                    }
                }
            }
            
        case .custom:
            // For custom intervals, check if this is a scheduled day
            if let interval = customInterval,
               let startDay = calendar.ordinality(of: .day, in: .era, for: startDate),
               let currentDay = calendar.ordinality(of: .day, in: .era, for: today) {
                
                let daysSinceStart = currentDay - startDay
                
                // If days since start is a multiple of the interval, it's scheduled
                if daysSinceStart >= 0 && daysSinceStart % interval == 0 {
                    // Today is a scheduled day, add all times
                    for time in timeOfDay {
                        let components = calendar.dateComponents([.hour, .minute], from: time)
                        var doseComponents = calendar.dateComponents([.year, .month, .day], from: today)
                        doseComponents.hour = components.hour
                        doseComponents.minute = components.minute
                        
                        if let doseTime = calendar.date(from: doseComponents) {
                            doseTimes.append(doseTime)
                        }
                    }
                }
            }
            
        case .asNeeded:
            // No scheduled times for as-needed medications
            break
        }
        
        return doseTimes.sorted()
    }
    
    // Helper to get the last dose date (implementation would depend on your dose tracking storage)
    func getLastDoseDate() -> Date? {
        // This would query your dose history - placeholder for now
        return nil
    }
    
    // Check if a dose is due now
    func isDoseDueNow(tolerance: TimeInterval = 60*60) -> Bool {
        guard let nextDose = getNextDoseTime() else { return false }
        
        let now = Date()
        let timeUntilDose = nextDose.timeIntervalSince(now)
        
        // Dose is due if it's within the tolerance period before or after the scheduled time
        return abs(timeUntilDose) <= tolerance
    }
    
    // Get next scheduled dose time
    func getNextDoseTime() -> Date? {
        let now = Date()
        let calendar = Calendar.current
        
        // Check if schedule is expired
        if let endDate = self.endDate, now > endDate {
            return nil
        }
        
        // Check if schedule hasn't started yet
        if now < startDate {
            // Return the first dose time on the start date
            if let firstTime = timeOfDay.first {
                let components = calendar.dateComponents([.hour, .minute], from: firstTime)
                var startComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
                startComponents.hour = components.hour
                startComponents.minute = components.minute
                
                return calendar.date(from: startComponents)
            }
            return nil
        }
        
        switch frequency {
        case .daily, .twiceDaily, .threeTimesDaily:
            // Find the next time today
            let today = calendar.startOfDay(for: now)
            
            // Sort times chronologically
            let sortedTimes = timeOfDay.sorted()
            
            // Look for the next time today
            for time in sortedTimes {
                let components = calendar.dateComponents([.hour, .minute], from: time)
                var doseComponents = calendar.dateComponents([.year, .month, .day], from: today)
                doseComponents.hour = components.hour
                doseComponents.minute = components.minute
                
                if let doseTime = calendar.date(from: doseComponents), doseTime > now {
                    return doseTime
                }
            }
            
            // If no times today, get the first time tomorrow
            if let firstTime = sortedTimes.first {
                let components = calendar.dateComponents([.hour, .minute], from: firstTime)
                var tomorrowComponents = calendar.dateComponents([.year, .month, .day], from: today)
                tomorrowComponents.day = (tomorrowComponents.day ?? 0) + 1
                tomorrowComponents.hour = components.hour
                tomorrowComponents.minute = components.minute
                
                return calendar.date(from: tomorrowComponents)
            }
            
        case .weekly:
            // Find the next weekday
            guard let daysOfWeek = daysOfWeek, !daysOfWeek.isEmpty else { return nil }
            
            let today = calendar.startOfDay(for: now)
            let currentWeekday = calendar.component(.weekday, from: now)
            
            // Convert from Sunday=1 to Monday=1 if needed
            let adjustedWeekday = currentWeekday % 7 + 1
            
            // Sort weekdays
            let sortedDays = daysOfWeek.sorted()
            
            // Find the next day this week
            for day in sortedDays {
                if day > adjustedWeekday {
                    let daysToAdd = day - adjustedWeekday
                    if let nextDate = calendar.date(byAdding: .day, value: daysToAdd, to: today),
                       let firstTime = timeOfDay.first {
                        let components = calendar.dateComponents([.hour, .minute], from: firstTime)
                        var doseComponents = calendar.dateComponents([.year, .month, .day], from: nextDate)
                        doseComponents.hour = components.hour
                        doseComponents.minute = components.minute
                        
                        return calendar.date(from: doseComponents)
                    }
                }
            }
            
            // If no days left this week, get the first day next week
            if let firstDay = sortedDays.first {
                let daysToAdd = 7 - adjustedWeekday + firstDay
                if let nextDate = calendar.date(byAdding: .day, value: daysToAdd, to: today),
                   let firstTime = timeOfDay.first {
                    let components = calendar.dateComponents([.hour, .minute], from: firstTime)
                    var doseComponents = calendar.dateComponents([.year, .month, .day], from: nextDate)
                    doseComponents.hour = components.hour
                    doseComponents.minute = components.minute
                    
                    return calendar.date(from: doseComponents)
                }
            }
            
        case .custom:
            // Handle custom interval in days
            guard let interval = customInterval else { return nil }
            
            // Find the next date based on start date and interval
            let startDay = calendar.startOfDay(for: startDate)
            let today = calendar.startOfDay(for: now)
            
            // Calculate days since start
            let components = calendar.dateComponents([.day], from: startDay, to: today)
            guard let daysSinceStart = components.day else { return nil }
            
            // Calculate next occurrence
            let daysToNextOccurrence = interval - (daysSinceStart % interval)
            let daysToAdd = daysToNextOccurrence == 0 ? interval : daysToNextOccurrence
            
            if let nextDate = calendar.date(byAdding: .day, value: daysToAdd, to: today),
               let firstTime = timeOfDay.first {
                
                let components = calendar.dateComponents([.hour, .minute], from: firstTime)
                var doseComponents = calendar.dateComponents([.year, .month, .day], from: nextDate)
                doseComponents.hour = components.hour
                doseComponents.minute = components.minute
                
                return calendar.date(from: doseComponents)
            }
            
        case .asNeeded:
            // No scheduled time for as-needed medications
            return nil
        }
        
        return nil
    }
    
    // More reliable method to determine if a schedule applies today
    func isActiveToday() -> Bool {
        let today = Date()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: today)
        
        // Check date range
        if startOfToday < startDate {
            return false
        }
        
        if let endDate = endDate, startOfToday > endDate {
            return false
        }
        
        // Check frequency
        switch frequency {
        case .daily, .twiceDaily, .threeTimesDaily:
            return true
            
        case .weekly:
            guard let daysOfWeek = daysOfWeek, !daysOfWeek.isEmpty else {
                return false
            }
            
            // Get today's weekday (1-7, Monday-Sunday)
            let weekday = calendar.component(.weekday, from: today)
            let adjustedWeekday = weekday % 7 + 1 // Convert from Sunday=1 to Monday=1
            
            return daysOfWeek.contains(adjustedWeekday)
            
        case .custom:
            guard let interval = customInterval, interval > 0 else {
                return false
            }
            
            // Calculate days since start
            let startDay = calendar.startOfDay(for: startDate)
            guard let daysSinceStart = calendar.dateComponents([.day], from: startDay, to: startOfToday).day else {
                return false
            }
            
            // Active if today is a multiple of the interval from start date
            return daysSinceStart >= 0 && daysSinceStart % interval == 0
            
        case .asNeeded:
            return true
        }
    }
}

extension MedicationSchedule: Equatable, Hashable {
    // Equatable implementation
    static func == (lhs: MedicationSchedule, rhs: MedicationSchedule) -> Bool {
        return lhs.id == rhs.id
    }
    
    // Hashable implementation
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

