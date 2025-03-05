//
//  AdherenceTrackingStore.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/4/25.
//
import SwiftUI
import CoreData
import Combine


class AdherenceTrackingStore: ObservableObject {
    private let context: NSManagedObjectContext
    
    @Published var medicationSchedules: [MedicationSchedule] = []
    @Published var medicationDoses: [MedicationDose] = []
    @Published var upcomingDoses: [UpcomingDose] = []
    @Published var todayDoses: [TodayDose] = []
    
    // For UI state
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    private var coreDataManager: CoreDataManager {
        return CoreDataManager(context: context)
    }
    
    // Struct for upcoming dose display
    struct UpcomingDose: Identifiable {
        var id: UUID { medicine.id } // Add Identifiable conformance
        var medicine: Medicine
        var scheduledTime: Date
        var schedule: MedicationSchedule
    }
    
    // Struct for today's doses display
    struct TodayDose: Identifiable {
        var id: UUID = UUID() // Add a unique identifier for each dose
        var medicine: Medicine
        var scheduledTime: Date
        var schedule: MedicationSchedule
        var status: MedicationDose.DoseStatus?
        var doseId: UUID?
    }
    
    // Direct method to ensure a schedule appears in Today view
    func forceScheduleToAppearInToday(_ schedule: MedicationSchedule) {
        print("Forcing schedule to appear in Today view: \(schedule.medicineName)")
        
        // 1. Add or update the schedule
        if let index = medicationSchedules.firstIndex(where: { $0.id == schedule.id }) {
            medicationSchedules[index] = schedule
        } else {
            medicationSchedules.append(schedule)
        }
        
        // 2. Save to storage
        saveSchedules()
        
        // 3. Completely rebuild today doses and upcoming doses
        rebuildTodayDoses()
        
        // 4. Force UI update
        objectWillChange.send()
    }
    
    // Complete rebuild of today and upcoming doses
    func rebuildTodayDoses() {
        print("Completely rebuilding today doses")
        
        // Clear existing data
        todayDoses = []
        upcomingDoses = []
        
        // Get all active schedules
        let activeSchedules = medicationSchedules.filter { $0.active }
        print("Active schedules count: \(activeSchedules.count)")
        
        // Process today's doses
        var newTodayDoses: [TodayDose] = []
        
        for schedule in activeSchedules {
            print("Processing schedule: \(schedule.medicineName)")
            let todayTimes = schedule.getTodayDoseTimes()
            print("- Has \(todayTimes.count) doses scheduled for today")
            
            if let medicine = getMedicine(byId: schedule.medicineId) {
                for time in todayTimes {
                    let recordedDose = findRecordedDose(forMedicine: schedule.medicineId, around: time)
                    
                    newTodayDoses.append(TodayDose(
                        id: UUID(),
                        medicine: medicine,
                        scheduledTime: time,
                        schedule: schedule,
                        status: recordedDose?.status,
                        doseId: recordedDose?.id
                    ))
                }
            } else {
                print("Warning: Could not find medicine for ID: \(schedule.medicineId)")
            }
        }
        
        // Sort and update
        todayDoses = newTodayDoses.sorted { $0.scheduledTime < $1.scheduledTime }
        
        // Process upcoming doses
        var newUpcomingDoses: [UpcomingDose] = []
        
        for schedule in activeSchedules {
            if let nextTime = schedule.getNextDoseTime(),
               let medicine = getMedicine(byId: schedule.medicineId) {
                newUpcomingDoses.append(UpcomingDose(
                    medicine: medicine,
                    scheduledTime: nextTime,
                    schedule: schedule
                ))
            }
        }
        
        // Sort and limit
        upcomingDoses = newUpcomingDoses.sorted { $0.scheduledTime < $1.scheduledTime }.prefix(5).map { $0 }
        
        print("Today doses rebuild complete. Count: \(todayDoses.count)")
    }
    
    // Method to clear all schedules for deleted medicines
    func cleanupDeletedMedicines() {
        // Get all medicines
        let allMedicines = medicineStore.medicines
        let medicineIds = Set(allMedicines.map { $0.id })
        
        // Find schedules for medicines that no longer exist
        let schedulesToRemove = medicationSchedules.filter { !medicineIds.contains($0.medicineId) }
        
        // Remove these schedules
        for schedule in schedulesToRemove {
            deleteSchedule(schedule)
        }
        
        // Also clean up doses for deleted medicines
        let dosesToRemove = medicationDoses.filter { !medicineIds.contains($0.medicineId) }
        for dose in dosesToRemove {
            deleteDose(dose)
        }
        
        // Update UI
        updateTodayDoses()
        updateUpcomingDoses()
    }
    
    // Access to the medicine store
    var medicineStore: MedicineStore {
        return MedicineStore(context: context)
    }
    
    func handleAllMedicinesDeleted() {
            // Clear all schedules and doses
            medicationSchedules.removeAll()
            medicationDoses.removeAll()
            
            // Save empty state
            saveSchedules()
            saveDoses()
            
            // Update UI
            updateTodayDoses()
            updateUpcomingDoses()
            
            // Clear cache
            clearCache()
    }
    
    // MARK: - Data Loading
    
    func loadData() {
        isLoading = true
        
        // Use background thread for data loading
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Load schedules and doses
            self.loadSchedules()
            self.loadDoses()
            
            // Return to main thread for UI updates
            DispatchQueue.main.async {
                // Process data for UI
                self.updateTodayDoses()
                self.updateUpcomingDoses()
                self.isLoading = false
            }
        }
    }

    
    func loadSchedules() {
        if let scheduleData = UserDefaults.standard.data(forKey: "medicationSchedules") {
            do {
                medicationSchedules = try JSONDecoder().decode([MedicationSchedule].self, from: scheduleData)
                
                // Validate each schedule
                medicationSchedules = medicationSchedules.map { schedule in
                    var validatedSchedule = schedule
                    
                    // Ensure each schedule has at least one time
                    if validatedSchedule.timeOfDay.isEmpty {
                        let defaultTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
                        validatedSchedule.timeOfDay = [defaultTime]
                    }
                    
                    // Ensure weekly schedules have days
                    if validatedSchedule.frequency == .weekly && (validatedSchedule.daysOfWeek == nil || validatedSchedule.daysOfWeek?.isEmpty == true) {
                        validatedSchedule.daysOfWeek = [1] // Monday as default
                    }
                    
                    return validatedSchedule
                }
            } catch {
                print("Error loading schedules: \(error)")
                medicationSchedules = []
            }
        }
        let coreDataManager = CoreDataManager(context: context)
        medicationSchedules = coreDataManager.fetchAllSchedules()
    }
    
    func loadDoses() {
        // For UserDefaults implementation
        if let doseData = UserDefaults.standard.data(forKey: "medicationDoses") {
            do {
                medicationDoses = try JSONDecoder().decode([MedicationDose].self, from: doseData)
            } catch {
                print("Error loading doses: \(error)")
                medicationDoses = []
            }
        }
        let coreDataManager = CoreDataManager(context: context)
        medicationDoses = coreDataManager.fetchAllDoses()
    }
    
    func addSchedule(_ schedule: MedicationSchedule) {
        DispatchQueue.main.async {
            self.medicationSchedules.append(schedule)
            self.saveSchedules()
            self.updateTodayDoses()
            self.updateUpcomingDoses()
        }
    }
    
    func updateSchedule(_ schedule: MedicationSchedule) {
        DispatchQueue.main.async {
            if let index = self.medicationSchedules.firstIndex(where: { $0.id == schedule.id }) {
                // Make a valid copy
                var validatedSchedule = schedule
                
                // Ensure each schedule has at least one time
                if validatedSchedule.timeOfDay.isEmpty {
                    let defaultTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
                    validatedSchedule.timeOfDay = [defaultTime]
                }
                
                // Ensure weekly schedules have days
                if validatedSchedule.frequency == .weekly && (validatedSchedule.daysOfWeek == nil || validatedSchedule.daysOfWeek?.isEmpty == true) {
                    validatedSchedule.daysOfWeek = [1] // Monday as default
                }
                
                self.medicationSchedules[index] = validatedSchedule
                self.saveSchedules()
                self.updateTodayDoses()
                self.updateUpcomingDoses()
            }
        }
    }
    
    // Improved deleteSchedule method that also cleans up related history
    func deleteSchedule(_ schedule: MedicationSchedule) {
        print("Deleting schedule for \(schedule.medicineName) (ID: \(schedule.id))")
        
        // First, remove the schedule from our array
        medicationSchedules.removeAll { $0.id == schedule.id }
        
        // Next, delete all dose records associated with this schedule's medicine
        // Only delete doses for this specific medicine
        let dosesToDelete = medicationDoses.filter { $0.medicineId == schedule.medicineId }
        
        // Log what we're deleting
        print("Found \(dosesToDelete.count) dose records to delete for medicine ID: \(schedule.medicineId)")
        
        // Remove these doses from our array
        medicationDoses.removeAll { $0.medicineId == schedule.medicineId }
        
        // Save changes to persistence
        saveSchedules()
        saveDoses()
        
        // Update UI
        updateTodayDoses()
        updateUpcomingDoses()
        
        // Force reload to ensure UI is completely updated
        objectWillChange.send()
    }
    
    // Method to completely refresh data from storage
   func refreshAllData() {
       medicationSchedules = []
       medicationDoses = []
       
       // Load from storage
       loadSchedules()
       loadDoses()
       
       // Update UI components
       updateTodayDoses()
       updateUpcomingDoses()
       
       // Force UI update
       objectWillChange.send()
   }
    
    func getSchedulesForMedicine(_ medicineId: UUID) -> [MedicationSchedule] {
        return medicationSchedules.filter { $0.medicineId == medicineId && $0.active }
    }
    
    func saveSchedules() {
        do {
            let scheduleData = try JSONEncoder().encode(medicationSchedules)
            UserDefaults.standard.set(scheduleData, forKey: "medicationSchedules")
        } catch {
            print("Error saving schedules: \(error)")
            errorMessage = "Error saving schedules"
        }
        // If we have CoreData implementation, use that instead
        for schedule in medicationSchedules {
            CoreDataManager(context: context).saveSchedule(schedule)
        }
    }
    
    // Add a more reliable schedule updating method that ensures Today view is updated
    func addScheduleAndUpdateViews(_ schedule: MedicationSchedule) {
        print("Adding schedule for \(schedule.medicineName) and updating views")
        
        // First add the schedule to our collection
        medicationSchedules.append(schedule)
        
        // Save to storage
        saveSchedules()
        
        // Force immediate update of today's doses and upcoming doses
        updateTodayDoses()
        updateUpcomingDoses()
        
        // Force UI update via objectWillChange
        objectWillChange.send()
        
        print("Schedule added successfully. Today doses count: \(todayDoses.count)")
    }
    
    func recordDose(_ dose: MedicationDose) {
        DispatchQueue.main.async {
            self.medicationDoses.append(dose)
            self.saveDoses()
            self.updateTodayDoses()
        }
    }
    
    func updateDose(_ dose: MedicationDose) {
        DispatchQueue.main.async {
            if let index = self.medicationDoses.firstIndex(where: { $0.id == dose.id }) {
                self.medicationDoses[index] = dose
                self.saveDoses()
                self.updateTodayDoses()
            }
        }
    }
    
    func deleteDose(_ dose: MedicationDose) {
        DispatchQueue.main.async {
            self.medicationDoses.removeAll { $0.id == dose.id }
            self.saveDoses()
            self.updateTodayDoses()
        }
    }
    
    func getDosesForMedicine(_ medicineId: UUID, startDate: Date, endDate: Date? = nil) -> [MedicationDose] {
        let end = endDate ?? Date()
        return medicationDoses.filter {
            $0.medicineId == medicineId &&
            $0.timestamp >= startDate &&
            $0.timestamp <= end
        }.sorted { $0.timestamp > $1.timestamp }
    }
    
    func getTodayDoses(for medicineId: UUID? = nil) -> [MedicationDose] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        if let medicineId = medicineId {
            return medicationDoses.filter {
                $0.medicineId == medicineId &&
                $0.timestamp >= startOfDay &&
                $0.timestamp < endOfDay
            }.sorted { $0.timestamp > $1.timestamp }
        } else {
            return medicationDoses.filter {
                $0.timestamp >= startOfDay &&
                $0.timestamp < endOfDay
            }.sorted { $0.timestamp > $1.timestamp }
        }
    }
    
    func saveDoses() {
        do {
            let doseData = try JSONEncoder().encode(medicationDoses)
            UserDefaults.standard.set(doseData, forKey: "medicationDoses")
        } catch {
            print("Error saving doses: \(error)")
            errorMessage = "Error saving dose records"
        }
    
        // If we have CoreData implementation, use that instead
        for dose in medicationDoses {
            CoreDataManager(context: context).saveDose(dose)
        }
}
    
    // MARK: - UI Data Processing
    
    func updateTodayDoses() {
        print("Updating today doses")
                
        // Get all active schedules
        let activeSchedules = medicationSchedules.filter { $0.active }
        print("Active schedules count: \(activeSchedules.count)")
        
        var doses: [TodayDose] = []
        
        // For each schedule, get today's dose times
        for schedule in activeSchedules {
            let todayTimes = schedule.getTodayDoseTimes()
            print("Schedule \(schedule.medicineName) has \(todayTimes.count) doses today")
            
            // Check if we have a matching medicine
            if let medicine = getMedicine(byId: schedule.medicineId) {
                for time in todayTimes {
                    // Check if this dose has been recorded
                    let recordedDose = findRecordedDose(forMedicine: schedule.medicineId, around: time)
                    
                    doses.append(TodayDose(
                        id: UUID(), // Ensure unique ID
                        medicine: medicine,
                        scheduledTime: time,
                        schedule: schedule,
                        status: recordedDose?.status,
                        doseId: recordedDose?.id
                    ))
                }
            } else {
                print("Warning: Could not find medicine for ID: \(schedule.medicineId)")
            }
        }
        
        // Sort by time
        todayDoses = doses.sorted { $0.scheduledTime < $1.scheduledTime }
        print("Updated today doses, new count: \(todayDoses.count)")
    }
    
    func updateUpcomingDoses() {
        // Get all active schedules
        let activeSchedules = medicationSchedules.filter { $0.active }
        
        var doses: [UpcomingDose] = []
        
        // For each schedule, get next dose time
        for schedule in activeSchedules {
            if let nextTime = schedule.getNextDoseTime(),
               let medicine = getMedicine(byId: schedule.medicineId) {
                doses.append(UpcomingDose(
                    medicine: medicine,
                    scheduledTime: nextTime,
                    schedule: schedule
                ))
            }
        }
        
        // Sort by time and limit to next 5
        upcomingDoses = doses.sorted { $0.scheduledTime < $1.scheduledTime }.prefix(5).map { $0 }
    }
    
    // MARK: - Helper Methods
    
    // Improved getMedicine method with better error handling
    func getMedicine(byId id: UUID) -> Medicine? {
        // First check our cache
        if let cached = medicineCache[id] {
            return cached
        }
        
        // Get from MedicineStore
        let medicineStore = MedicineStore(context: context)
        if let medicine = medicineStore.medicines.first(where: { $0.id == id }) {
            // Cache for future use
            medicineCache[id] = medicine
            return medicine
        }
        
        return nil
    }
    
    // Add a cache for medicines to improve performance
    private var medicineCache: [UUID: Medicine] = [:]
    
    // Clear cache when needed
    func clearCache() {
        medicineCache.removeAll()
    }
    
    func findRecordedDose(forMedicine medicineId: UUID, around time: Date, tolerance: TimeInterval = 60*30) -> MedicationDose? {
        // Find a dose recorded within +/- tolerance of the scheduled time
        let startTime = time.addingTimeInterval(-tolerance)
        let endTime = time.addingTimeInterval(tolerance)
        
        return medicationDoses.first { dose in
            dose.medicineId == medicineId &&
            dose.timestamp >= startTime &&
            dose.timestamp <= endTime
        }
    }
    
    func handleError(_ error: Error, operation: String) {
        print("Error during \(operation): \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.errorMessage = "Error: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Adherence Analytics
    
    func calculateAdherenceRate(forMedicine medicineId: UUID, in days: Int = 30) -> Double {
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) else {
            return 0.0
        }
        
        // Get schedules for this medicine
        let schedules = getSchedulesForMedicine(medicineId)
        if schedules.isEmpty {
            return 0.0
        }
        
        var expectedDoses = 0
        var takenDoses = 0
        
        // Calculate day by day
        var currentDate = startDate
        while currentDate <= endDate {
            for schedule in schedules {
                // Skip if schedule wasn't active on this date
                if currentDate < schedule.startDate ||
                    (schedule.endDate != nil && currentDate > schedule.endDate!) {
                    continue
                }
                
                // Count expected doses for this day based on schedule
                switch schedule.frequency {
                case .daily:
                    expectedDoses += 1
                case .twiceDaily:
                    expectedDoses += 2
                case .threeTimesDaily:
                    expectedDoses += 3
                case .weekly:
                    if let daysOfWeek = schedule.daysOfWeek {
                        let weekday = calendar.component(.weekday, from: currentDate)
                        let adjustedWeekday = weekday % 7 + 1
                        if daysOfWeek.contains(adjustedWeekday) {
                            expectedDoses += 1
                        }
                    }
                case .custom:
                    // For custom intervals, check if this is a scheduled day
                    if let interval = schedule.customInterval,
                       let startDay = calendar.ordinality(of: .day, in: .era, for: schedule.startDate),
                       let currentDay = calendar.ordinality(of: .day, in: .era, for: currentDate) {
                        
                        let daysSinceStart = currentDay - startDay
                        if daysSinceStart % interval == 0 {
                            expectedDoses += 1
                        }
                    }
                case .asNeeded:
                    // As-needed medications don't have expected doses
                    break
                }
            }
            
            // Advance to next day
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        // Get actual taken doses in the period
        let recordedDoses = getDosesForMedicine(medicineId, startDate: startDate, endDate: endDate)
        takenDoses = recordedDoses.filter { $0.taken }.count
        
        // Calculate adherence rate
        return expectedDoses > 0 ? Double(takenDoses) / Double(expectedDoses) * 100.0 : 0.0
    }
    
    // Get streaks for medicine (consecutive days with all doses taken)
    func getCurrentStreak(forMedicine medicineId: UUID) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var currentStreak = 0
        var dayToCheck = today
        
        // Go backwards day by day until streak breaks
        while true {
            let dayStart = calendar.startOfDay(for: dayToCheck)
            let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            
            // Get schedules active on this day
            let schedules = getSchedulesForMedicine(medicineId).filter { schedule in
                dayToCheck >= schedule.startDate &&
                (schedule.endDate == nil || dayToCheck <= schedule.endDate!)
            }
            
            // If no schedules, break streak
            if schedules.isEmpty {
                break
            }
            
            // Count expected and taken doses for this day
            var expectedDoses = 0
            var takenDoses = 0
            
            for schedule in schedules {
                let doseTimes = getDoseTimesForDay(schedule: schedule, date: dayToCheck)
                expectedDoses += doseTimes.count
                
                // Count taken doses
                for doseTime in doseTimes {
                    if let dose = findRecordedDose(forMedicine: medicineId, around: doseTime), dose.taken {
                        takenDoses += 1
                    }
                }
            }
            
            // If no expected doses, or not all doses taken, break streak
            if expectedDoses == 0 || takenDoses < expectedDoses {
                break
            }
            
            // Increment streak and go to previous day
            currentStreak += 1
            if let previousDay = calendar.date(byAdding: .day, value: -1, to: dayToCheck) {
                dayToCheck = previousDay
            } else {
                break
            }
        }
        
        return currentStreak
    }
    
    // Helper to get dose times for a specific day based on schedule
    func getDoseTimesForDay(schedule: MedicationSchedule, date: Date) -> [Date] {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        var doseTimes: [Date] = []
        
        switch schedule.frequency {
        case .daily, .twiceDaily, .threeTimesDaily:
            // Add all times for the day
            for time in schedule.timeOfDay {
                let components = calendar.dateComponents([.hour, .minute], from: time)
                var doseComponents = calendar.dateComponents([.year, .month, .day], from: day)
                doseComponents.hour = components.hour
                doseComponents.minute = components.minute
                
                if let doseTime = calendar.date(from: doseComponents) {
                    doseTimes.append(doseTime)
                }
            }
            
        case .weekly:
            // Check if the day is a scheduled day
            let weekday = calendar.component(.weekday, from: date)
            let adjustedWeekday = weekday % 7 + 1
            
            if let daysOfWeek = schedule.daysOfWeek, daysOfWeek.contains(adjustedWeekday) {
                // Add all times for the day
                for time in schedule.timeOfDay {
                    let components = calendar.dateComponents([.hour, .minute], from: time)
                    var doseComponents = calendar.dateComponents([.year, .month, .day], from: day)
                    doseComponents.hour = components.hour
                    doseComponents.minute = components.minute
                    
                    if let doseTime = calendar.date(from: doseComponents) {
                        doseTimes.append(doseTime)
                    }
                }
            }
            
        case .custom:
            // Check if this is a scheduled day based on interval
            if let interval = schedule.customInterval,
               let startDay = calendar.ordinality(of: .day, in: .era, for: schedule.startDate),
               let currentDay = calendar.ordinality(of: .day, in: .era, for: date) {
                
                let daysSinceStart = currentDay - startDay
                if daysSinceStart % interval == 0 {
                    // Add all times for the day
                    for time in schedule.timeOfDay {
                        let components = calendar.dateComponents([.hour, .minute], from: time)
                        var doseComponents = calendar.dateComponents([.year, .month, .day], from: day)
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
    
    // Helper method to check if a medicine has any schedules
    func hasSchedule(for medicineId: UUID) -> Bool {
        return medicationSchedules.contains { schedule in
            return schedule.medicineId == medicineId
        }
    }
    
    // Get all medicine IDs that have schedules
    func getMedicinesWithSchedules() -> Set<UUID> {
        return Set(medicationSchedules.map { $0.medicineId })
    }
    
    // Helper method to get a dose by its ID
    func getDoseById(_ doseId: UUID) -> MedicationDose? {
        return medicationDoses.first { $0.id == doseId }
    }
}
