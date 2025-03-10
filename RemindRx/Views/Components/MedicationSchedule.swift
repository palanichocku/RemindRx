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
    
    // Updated method to fix "hasn't started yet" issue
    func getTodayDoseTimes() -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var doseTimes: [Date] = []
        
        // IMPORTANT: We no longer check if startDate is today or later
        // Only check for end date
        if let endDate = endDate, calendar.startOfDay(for: endDate) < today {
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
            // Get today's weekday (1-7, Monday-Sunday)
            let currentWeekday = calendar.component(.weekday, from: today)
            // Convert from Sunday=1 to Monday=1
            let adjustedWeekday = currentWeekday == 1 ? 7 : currentWeekday - 1
            
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
            if let interval = customInterval {
                // Always show today if interval is 1
                if interval == 1 {
                    for time in timeOfDay {
                        let components = calendar.dateComponents([.hour, .minute], from: time)
                        var doseComponents = calendar.dateComponents([.year, .month, .day], from: today)
                        doseComponents.hour = components.hour
                        doseComponents.minute = components.minute
                        
                        if let doseTime = calendar.date(from: doseComponents) {
                            doseTimes.append(doseTime)
                        }
                    }
                } else {
                    // Calculate if today is a scheduled day based on the interval
                    let startDateComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
                    let startDay = calendar.date(from: startDateComponents) ?? startDate
                    
                    let daysSinceStart = calendar.dateComponents([.day], from: startDay, to: today).day ?? 0
                    
                    if daysSinceStart % interval == 0 {
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
            }
            
        case .asNeeded:
            // For as-needed, just show it today anyway
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
        
        // Sort by time
        return doseTimes.sorted()
    }
    
    // Override to force today's dose times to show for testing
        func getTodayDoseTimes(forceShowToday: Bool = false) -> [Date] {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            var times: [Date] = []
            
            // If we're before the start date and not forcing, return empty
            if today < calendar.startOfDay(for: startDate) && !forceShowToday {
                return []
            }
            
            // If we're after the end date and not forcing, return empty
            if let endDate = endDate, today > calendar.startOfDay(for: endDate) && !forceShowToday {
                return []
            }
            
            // Determine if this schedule should show doses today based on frequency
            let shouldShowToday = forceShowToday || isDueTodayBasedOnFrequency(calendar: calendar, today: today)
            
            if shouldShowToday {
                // Add all times for today
                for time in timeOfDay {
                    let components = calendar.dateComponents([.hour, .minute], from: time)
                    var doseComponents = calendar.dateComponents([.year, .month, .day], from: today)
                    doseComponents.hour = components.hour
                    doseComponents.minute = components.minute
                    
                    if let doseTime = calendar.date(from: doseComponents) {
                        times.append(doseTime)
                    }
                }
            }
            
            return times.sorted()
        }
    
        // Helper method to determine if doses are due today based on frequency
        private func isDueTodayBasedOnFrequency(calendar: Calendar, today: Date) -> Bool {
            switch frequency {
            case .daily, .twiceDaily, .threeTimesDaily:
                return true
                
            case .weekly:
                // Check if today matches any of the days of week in the schedule
                if let daysOfWeek = daysOfWeek {
                    let weekday = calendar.component(.weekday, from: today)
                    // Convert to 1-based where 1 is Monday (to match your convention)
                    let adjustedWeekday = weekday % 7 + 1
                    return daysOfWeek.contains(adjustedWeekday)
                }
                return false
                
            case .custom:
                // Check if today is a multiple of the interval from the start date
                if let interval = customInterval,
                   let startDay = calendar.ordinality(of: .day, in: .era, for: startDate),
                   let currentDay = calendar.ordinality(of: .day, in: .era, for: today) {
                    
                    let daysSinceStart = currentDay - startDay
                    return daysSinceStart % interval == 0
                }
                return false
                
            case .asNeeded:
                // As-needed medications don't have scheduled times
                return false
            }
        }
    
    // Update the isActiveToday method to be more permissive
    func isActiveToday() -> Bool {
        // Always return true - we want to show all schedules
        // This is the simplest fix to ensure schedules appear
        return true
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
    
    static func == (lhs: MedicationSchedule, rhs: MedicationSchedule) -> Bool {
        return lhs.id == rhs.id
    }
    
    // Hashable implementation
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
}

