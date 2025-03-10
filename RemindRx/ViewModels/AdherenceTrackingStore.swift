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
    let context: NSManagedObjectContext
    
    @Published var medicationSchedules: [MedicationSchedule] = []
    @Published var medicationDoses: [MedicationDose] = []
    @Published var upcomingDoses: [UpcomingDose] = []
    @Published var todayDoses: [TodayDose] = []
    
    // For UI state
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // Add property to store history records
    @Published var historyRecords: [MedicationHistoryRecord] = []
    // Add property for retention period settings
    @Published var historyRetentionPeriod: RetentionPeriod = .months6
    
    // Define retention period enum
    enum RetentionPeriod: String, CaseIterable, Identifiable, Codable {
        case weeks2 = "2 Weeks"
        case month1 = "1 Month"
        case months3 = "3 Months"
        case months6 = "6 Months"
        case year1 = "1 Year"
        case years2 = "2 Years"
        case forever = "Forever"
        
        var id: String { self.rawValue }
        
        var days: Int {
            switch self {
            case .weeks2: return 14
            case .month1: return 30
            case .months3: return 90
            case .months6: return 180
            case .year1: return 365
            case .years2: return 730
            case .forever: return Int.max
            }
        }
    }
    
    init(context: NSManagedObjectContext) {
        print("Initializing AdherenceTrackingStore")
        self.context = context
        // Set up notification listeners for medicine deletion
        setupNotificationListeners()
        // Immediately load data on initialization
        self.loadSchedules()
        self.loadDoses()
        self.updateTodayDoses()
        self.updateUpcomingDoses()
        // Add this to init
        func setupHistoryRecords() {
            loadHistoryRecords()
            loadRetentionSettings()
        }
    }
    
    // Method to add a record to history
    func addToHistory(medicineId: UUID, medicineName: String, scheduledTime: Date, recordedTime: Date, status: MedicationDose.DoseStatus, notes: String? = nil) {
        let record = MedicationHistoryRecord(
            medicineId: medicineId,
            medicineName: medicineName,
            scheduledTime: scheduledTime,
            recordedTime: recordedTime,
            status: status,
            notes: notes
        )
        
        // Add to our collection
        historyRecords.append(record)
        
        // Save to persistence
        saveHistoryRecords()
        
        // Trim old records based on retention settings
        applyRetentionPolicy()
        
        print("✅ Added history record for \(medicineName)")
    }
    
    // Load history records from storage
    func loadHistoryRecords() {
        // Try to load from Core Data first
        let coreDataManager = CoreDataManager(context: context)
        historyRecords = coreDataManager.fetchAllHistoryRecords()
        
        // Also try from UserDefaults as fallback
        if historyRecords.isEmpty, let data = UserDefaults.standard.data(forKey: "medicationHistory") {
            do {
                historyRecords = try JSONDecoder().decode([MedicationHistoryRecord].self, from: data)
                print("Loaded \(historyRecords.count) history records from UserDefaults")
            } catch {
                print("Error loading history records: \(error)")
            }
        }
        
        print("Loaded \(historyRecords.count) history records")
    }

    // Save history records to storage
    func saveHistoryRecords() {
        do {
            // Save to UserDefaults
            let data = try JSONEncoder().encode(historyRecords)
            UserDefaults.standard.set(data, forKey: "medicationHistory")
            
            // Also save to Core Data
            let coreDataManager = CoreDataManager(context: context)
            for record in historyRecords {
                coreDataManager.saveHistoryRecord(record)
            }
            
            print("Saved \(historyRecords.count) history records")
        } catch {
            print("Error saving history records: \(error)")
        }
    }

    // Save retention period setting
    func saveRetentionSettings() {
        UserDefaults.standard.set(historyRetentionPeriod.rawValue, forKey: "historyRetentionPeriod")
    }

    // Load retention period setting
    func loadRetentionSettings() {
        if let periodString = UserDefaults.standard.string(forKey: "historyRetentionPeriod"),
           let period = RetentionPeriod(rawValue: periodString) {
            historyRetentionPeriod = period
        } else {
            // Default to 6 months if not set
            historyRetentionPeriod = .months6
        }
    }

    // Apply retention policy to remove old records
    func applyRetentionPolicy() {
        // If retention is forever, don't delete anything
        if historyRetentionPeriod == .forever {
            return
        }
        
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -historyRetentionPeriod.days, to: Date()) ?? Date()
        
        // Count before
        let beforeCount = historyRecords.count
        
        // Remove old records
        historyRecords.removeAll { $0.recordedTime < cutoffDate }
        
        // Count after
        let afterCount = historyRecords.count
        
        if beforeCount != afterCount {
            print("Retention policy removed \(beforeCount - afterCount) records older than \(historyRetentionPeriod.rawValue)")
            
            // Save the updated records
            saveHistoryRecords()
        }
    }
    
    func applyRetentionPolicy(days: Int) {
        if days == Int.max {
            print("Retention set to 'Forever', not deleting any records")
            return
        }
        
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        // Count before
        let beforeCount = historyRecords.count
        
        // Remove old records
        historyRecords.removeAll { $0.recordedTime < cutoffDate }
        
        // Count after
        let afterCount = historyRecords.count
        
        if beforeCount != afterCount {
            print("Retention policy removed \(beforeCount - afterCount) records older than \(days) days")
            
            // Save the updated records
            saveHistoryRecords()
            
            // Also delete from Core Data
            let coreDataManager = CoreDataManager(context: context)
            coreDataManager.deleteHistoryRecordsBeforeDate(cutoffDate)
        }
    }

    // Get history records for a specific medicine
    func getHistoryForMedicine(_ medicineId: UUID) -> [MedicationHistoryRecord] {
        return historyRecords.filter { $0.medicineId == medicineId }
            .sorted { $0.recordedTime > $1.recordedTime }
    }

    // Get all history records within a date range
    func getHistoryInRange(start: Date, end: Date? = nil) -> [MedicationHistoryRecord] {
        let endDate = end ?? Date()
        
        return historyRecords.filter {
            $0.recordedTime >= start && $0.recordedTime <= endDate
        }.sorted { $0.recordedTime > $1.recordedTime }
    }

    // Get recent history (last 7 days by default)
    func getRecentHistory(days: Int = 7) -> [MedicationHistoryRecord] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        return getHistoryInRange(start: startDate)
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
    
    // Add this method to AdherenceTrackingStore
    
    
    
    // Set up notification listeners for medicine deletion events
    func setupNotificationListeners() {
        print("Setting up notification listeners for medicine deletion events")
        
        // Listen for individual medicine deletion
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMedicineDeletion(_:)),
            name: NSNotification.Name("MedicineDeletedCleanup"),
            object: nil
        )
        
        // Listen for all medicines deletion
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAllMedicinesDeletion),
            name: NSNotification.Name("AllMedicinesDeletedCleanup"),
            object: nil
        )
    }
    
    
    // Add this diagnostic method to AdherenceTrackingStore
    func diagnosticScheduleCheck() {
        print("\n===== DIAGNOSTIC SCHEDULE CHECK =====")
        print("Total schedules in store: \(medicationSchedules.count)")
        
        // Show active schedules
        let activeSchedules = medicationSchedules.filter { $0.active }
        print("Active schedules: \(activeSchedules.count)")
        
        for (index, schedule) in activeSchedules.enumerated() {
            print("\nSchedule #\(index + 1): \(schedule.medicineName) (ID: \(schedule.id))")
            print("  Medicine ID: \(schedule.medicineId)")
            print("  Start date: \(schedule.startDate)")
            print("  End date: \(schedule.endDate?.description ?? "None")")
            print("  Frequency: \(schedule.frequency)")
            print("  Times of day: \(schedule.timeOfDay.count)")
            
            if let medicine = getMedicine(byId: schedule.medicineId) {
                print("  ✅ Medicine found: \(medicine.name)")
            } else {
                print("  ❌ Medicine NOT found for ID: \(schedule.medicineId)")
            }
            
            // Check today's times
            let todayTimes = schedule.getTodayDoseTimes()
            print("  Today's dose times: \(todayTimes.count)")
            for time in todayTimes {
                print("    - \(formatTime(time))")
            }
            
            // Check next time
            if let nextTime = schedule.getNextDoseTime() {
                print("  Next dose time: \(formatDateTime(nextTime))")
            } else {
                print("  ❌ No next dose time found")
            }
        }
        
        // Check today doses
        print("\nToday's doses: \(todayDoses.count)")
        for (index, dose) in todayDoses.enumerated() {
            print("  Dose #\(index + 1): \(dose.medicine.name) at \(formatTime(dose.scheduledTime))")
            if let status = dose.status {
                print("    Status: \(status)")
            } else {
                print("    Status: Pending")
            }
        }
        
        // Check upcoming doses
        print("\nUpcoming doses: \(upcomingDoses.count)")
        for (index, dose) in upcomingDoses.enumerated() {
            print("  Dose #\(index + 1): \(dose.medicine.name) at \(formatDateTime(dose.scheduledTime))")
        }
        
        print("\n===== FORCE REBUILDING TODAY'S DOSES =====")
        forceSchedulesToShowToday()
        print("After force: Today's doses count: \(todayDoses.count)")
        print("================================================\n")
    }
    
    // Helper function to format time for diagnostic output
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
    
    // Helper function to format date and time for diagnostic output
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
    
    // Handle notification for single medicine deletion
    @objc func handleMedicineDeletion(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let medicineId = userInfo["medicineId"] as? UUID else {
            print("⚠️ Medicine deletion notification received with no valid medicineId")
            return
        }
        
        print("🧹 AdherenceTrackingStore cleaning up data for deleted medicine \(medicineId)")
        
        // Find all schedules for this medicine
        let schedulesToDelete = medicationSchedules.filter { $0.medicineId == medicineId }
        
        // Delete each schedule (which also cleans up associated doses)
        for schedule in schedulesToDelete {
            print("  - Deleting schedule: \(schedule.id)")
            deleteSchedule(schedule)
        }
        
        // Find and remove any remaining doses for this medicine
        medicationDoses.removeAll { $0.medicineId == medicineId }
        
        // Save changes to persistence
        saveDoses()
        
        // Also delete from Core Data for complete cleanup
        let coreDataManager = CoreDataManager(context: context)
        deleteDosesForMedicine(medicineId: medicineId)
        deleteSchedulesForMedicine(medicineId: medicineId)
        
        // Force refresh of UI data
        updateTodayDoses()
        updateUpcomingDoses()
        
        // Force UI update
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        
        print("✅ Cleanup complete for medicine \(medicineId)")
    }
    
    // Handle notification for all medicines deletion
    @objc func handleAllMedicinesDeletion() {
        print("🧹 AdherenceTrackingStore cleaning up ALL data after medicines deletion")
        
        // Just use the existing method
        handleAllMedicinesDeleted()
    }
    
    // Helper method to delete doses for a specific medicine
    func deleteDosesForMedicine(medicineId: UUID) {
        let fetchRequest: NSFetchRequest<DoseEntity> = DoseEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "medicineId == %@", medicineId as CVarArg)
        
        do {
            let doses = try context.fetch(fetchRequest)
            print("Found \(doses.count) dose records to delete from Core Data")
            
            for dose in doses {
                context.delete(dose)
            }
            
            try context.save()
        } catch {
            print("Error deleting doses from Core Data: \(error)")
        }
    }
    
    // Helper method to delete schedules for a specific medicine
    func deleteSchedulesForMedicine(medicineId: UUID) {
        let fetchRequest: NSFetchRequest<ScheduleEntity> = ScheduleEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "medicineId == %@", medicineId as CVarArg)
        
        do {
            let schedules = try context.fetch(fetchRequest)
            print("Found \(schedules.count) schedule records to delete from Core Data")
            
            for schedule in schedules {
                context.delete(schedule)
            }
            
            try context.save()
        } catch {
            print("Error deleting schedules from Core Data: \(error)")
        }
    }
    
    func handleAllMedicinesDeleted() {
        print("🧹 Cleaning up all data after medicines deletion")
        
        // Clear all data in memory
        medicationSchedules.removeAll()
        medicationDoses.removeAll()
        todayDoses.removeAll()
        upcomingDoses.removeAll()
        
        // Clear medicine cache
        clearCache()
        
        // Clear all UserDefaults data
        UserDefaults.standard.removeObject(forKey: "medicationSchedules")
        UserDefaults.standard.removeObject(forKey: "medicationDoses")
        
        // Delete all data from Core Data
        let coreDataManager = CoreDataManager(context: context)
        coreDataManager.deleteAllSchedules()
        coreDataManager.deleteAllDoses()
        
        // Notify UI
        print("✅ All tracking data cleared")
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    // Helper method to check if data is clean
    func verifyDataCleanup() -> Bool {
        let hasNoSchedules = medicationSchedules.isEmpty
        let hasNoDoses = medicationDoses.isEmpty
        let hasNoTodayDoses = todayDoses.isEmpty
        let hasNoUpcomingDoses = upcomingDoses.isEmpty
        
        let userDefaultsSchedules = UserDefaults.standard.data(forKey: "medicationSchedules") == nil
        let userDefaultsDoses = UserDefaults.standard.data(forKey: "medicationDoses") == nil
        
        // Check Core Data
        let schedulesFetchRequest: NSFetchRequest<ScheduleEntity> = ScheduleEntity.fetchRequest()
        let dosesFetchRequest: NSFetchRequest<DoseEntity> = DoseEntity.fetchRequest()
        
        var hasNoSchedulesInCoreData: Bool
        let hasNoDosesInCoreData: Bool
        
        do {
            hasNoSchedulesInCoreData = try context.count(for: schedulesFetchRequest) == 0
            hasNoDosesInCoreData = try context.count(for: dosesFetchRequest) == 0
        } catch {
            print("Error verifying Core Data cleanup: \(error)")
            hasNoSchedulesInCoreData = false
            hasNoDosesInCoreData = false
        }
        
        let isClean = hasNoSchedules && hasNoDoses && hasNoTodayDoses && hasNoUpcomingDoses &&
        userDefaultsSchedules && userDefaultsDoses &&
        hasNoSchedulesInCoreData && hasNoDosesInCoreData
        
        print("Data cleanup verification:")
        print("- Memory schedules: \(hasNoSchedules ? "Clean ✓" : "Dirty ✗")")
        print("- Memory doses: \(hasNoDoses ? "Clean ✓" : "Dirty ✗")")
        print("- Memory today doses: \(hasNoTodayDoses ? "Clean ✓" : "Dirty ✗")")
        print("- Memory upcoming doses: \(hasNoUpcomingDoses ? "Clean ✓" : "Dirty ✗")")
        print("- UserDefaults schedules: \(userDefaultsSchedules ? "Clean ✓" : "Dirty ✗")")
        print("- UserDefaults doses: \(userDefaultsDoses ? "Clean ✓" : "Dirty ✗")")
        print("- CoreData schedules: \(hasNoSchedulesInCoreData ? "Clean ✓" : "Dirty ✗")")
        print("- CoreData doses: \(hasNoDosesInCoreData ? "Clean ✓" : "Dirty ✗")")
        print("Overall status: \(isClean ? "Clean ✓" : "Dirty ✗")")
        
        return isClean
    }
    
    // Force cleanup in case data is still found
    func forceCleanup() {
        print("🧨 Forcing complete data cleanup")
        
        // Clear all in-memory data
        medicationSchedules.removeAll()
        medicationDoses.removeAll()
        todayDoses.removeAll()
        upcomingDoses.removeAll()
        medicineCache.removeAll()
        
        // Clear all UserDefaults data
        UserDefaults.standard.removeObject(forKey: "medicationSchedules")
        UserDefaults.standard.removeObject(forKey: "medicationDoses")
        
        // Delete all Core Data entities
        let coreDataManager = CoreDataManager(context: context)
        coreDataManager.deleteAllSchedules()
        coreDataManager.deleteAllDoses()
        
        // Verify the cleanup
        let isClean = verifyDataCleanup()
        
        // If still not clean, try more aggressive approach
        if !isClean {
            print("⚠️ Standard cleanup failed, attempting more aggressive cleanup")
            
            // Try direct Core Data deletion
            let schedulesFetchRequest: NSFetchRequest<ScheduleEntity> = ScheduleEntity.fetchRequest()
            let dosesFetchRequest: NSFetchRequest<DoseEntity> = DoseEntity.fetchRequest()
            
            do {
                let schedules = try context.fetch(schedulesFetchRequest)
                let doses = try context.fetch(dosesFetchRequest)
                
                for schedule in schedules {
                    context.delete(schedule)
                }
                
                for dose in doses {
                    context.delete(dose)
                }
                
                try context.save()
                print("✅ Manually deleted all entities")
            } catch {
                print("❌ Error during aggressive cleanup: \(error)")
            }
        }
        
        // Notify UI
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    
    // Update forceSchedulesToShowToday to fix times before processing
    func forceSchedulesToShowToday() {
        print("⚡️ Forcing schedules to show in Today tab")
        
        // First check and fix any schedules with empty times
        checkAndFixScheduleTimes()
        
        // Clear today's doses completely
        todayDoses = []
        
        // Process all active schedules
        for schedule in medicationSchedules where schedule.active {
            print("Processing schedule for Today tab: \(schedule.medicineName)")
            
            // Skip if schedule has no times (this shouldn't happen after the fix, but just in case)
            if schedule.timeOfDay.isEmpty {
                print("⚠️ Schedule has no times defined, adding a default time")
                
                // Create a mutable copy and add a default time
                var mutableSchedule = schedule
                let defaultTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
                mutableSchedule.timeOfDay = [defaultTime]
                
                // Get medicine
                if let medicine = getMedicine(byId: schedule.medicineId) {
                    let doseTime = defaultTime
                    
                    // Add to today's doses with defaultTime
                    todayDoses.append(TodayDose(
                        id: UUID(),
                        medicine: medicine,
                        scheduledTime: doseTime,
                        schedule: mutableSchedule,
                        status: nil,
                        doseId: nil
                    ))
                }
                
                continue
            }
            
            // Get medicine
            if let medicine = getMedicine(byId: schedule.medicineId) {
                // Force at least today's times regardless of date/frequency checks
                for time in schedule.timeOfDay {
                    let calendar = Calendar.current
                    let today = calendar.startOfDay(for: Date())
                    let components = calendar.dateComponents([.hour, .minute], from: time)
                    var doseComponents = calendar.dateComponents([.year, .month, .day], from: today)
                    doseComponents.hour = components.hour
                    doseComponents.minute = components.minute
                    
                    if let doseTime = calendar.date(from: doseComponents) {
                        // Check if this dose has been recorded
                        let recordedDose = findRecordedDose(forMedicine: schedule.medicineId, around: doseTime)
                        
                        // Add to today's doses
                        todayDoses.append(TodayDose(
                            id: UUID(),
                            medicine: medicine,
                            scheduledTime: doseTime,
                            schedule: schedule,
                            status: recordedDose?.status,
                            doseId: recordedDose?.id
                        ))
                    }
                }
            }
        }
        
        // Sort by time
        todayDoses.sort { $0.scheduledTime < $1.scheduledTime }
        print("✅ Forced today doses count: \(todayDoses.count)")
        
        // Also update upcoming doses
        updateUpcomingDoses(forceShow: true)
    }
    
    
    // 2. Update the refreshAllData method to call forceSchedulesToShowToday
    func refreshAllData() {
        print("🔄 Starting full data refresh")
        isLoading = true
        
        // Clear existing data
        medicineCache.removeAll()
        
        // Load from all sources
        let coreDataManager = CoreDataManager(context: context)
        medicationSchedules = coreDataManager.fetchAllSchedules()
        medicationDoses = coreDataManager.fetchAllDoses()
        
        // Also load from UserDefaults as fallback
        if let scheduleData = UserDefaults.standard.data(forKey: "medicationSchedules") {
            do {
                let userDefaultsSchedules = try JSONDecoder().decode([MedicationSchedule].self, from: scheduleData)
                
                // Merge with core data schedules, avoiding duplicates
                let existingIds = Set(medicationSchedules.map { $0.id })
                for schedule in userDefaultsSchedules {
                    if !existingIds.contains(schedule.id) {
                        medicationSchedules.append(schedule)
                    }
                }
            } catch {
                print("❌ Error loading schedules from UserDefaults: \(error)")
            }
        }
        
        // Now FORCE schedules to show in Today tab instead of doing a standard rebuild
        forceSchedulesToShowToday()
        
        // Update upcoming doses
        updateUpcomingDoses()
        
        isLoading = false
        print("✅ Full data refresh complete")
        
        // Force UI update
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    // Add this validation method to your AdherenceTrackingStore
    func validateScheduleBeforeSaving(_ schedule: MedicationSchedule) -> MedicationSchedule {
        var validatedSchedule = schedule
        
        // Ensure at least one time is specified
        if validatedSchedule.timeOfDay.isEmpty {
            print("⚠️ Adding default 9:00 AM time to new schedule")
            let defaultTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
            validatedSchedule.timeOfDay = [defaultTime]
        }
        
        // Ensure weekly schedules have at least one day selected
        if validatedSchedule.frequency == .weekly && (validatedSchedule.daysOfWeek == nil || validatedSchedule.daysOfWeek?.isEmpty == true) {
            print("⚠️ Adding default Monday to weekly schedule")
            validatedSchedule.daysOfWeek = [1] // Monday
        }
        
        // Ensure custom schedules have an interval
        if validatedSchedule.frequency == .custom && validatedSchedule.customInterval == nil {
            print("⚠️ Adding default 1-day interval to custom schedule")
            validatedSchedule.customInterval = 1
        }
        
        return validatedSchedule
    }
    
    // Add this method to check and fix schedules with empty times
    func checkAndFixScheduleTimes() {
        print("🔧 Checking and fixing schedule times")
        var hasChanges = false
        
        for (index, schedule) in medicationSchedules.enumerated() {
            if schedule.timeOfDay.isEmpty {
                print("⚠️ Found schedule with empty times: \(schedule.medicineName)")
                
                // Create a default time (9 AM)
                let calendar = Calendar.current
                var defaultTime = DateComponents()
                defaultTime.hour = 9
                defaultTime.minute = 0
                
                if let defaultDate = calendar.date(from: defaultTime) {
                    // Create a mutable copy of the schedule
                    var updatedSchedule = schedule
                    updatedSchedule.timeOfDay = [defaultDate]
                    
                    // Update in our array
                    medicationSchedules[index] = updatedSchedule
                    
                    print("✅ Fixed schedule by adding default 9:00 AM time")
                    hasChanges = true
                }
            }
        }
        
        if hasChanges {
            // Save changes
            saveSchedules()
            
            // Update the UI
            updateTodayDoses()
            updateUpcomingDoses()
            
            print("✅ Saved schedule time fixes")
        }
    }
    
    // Add this method to properly create and save schedules
    func forceSaveAndShowSchedule(_ schedule: MedicationSchedule) {
        // Create a valid copy with yesterday as the start date
        var validatedSchedule = schedule
        validatedSchedule.startDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        
        // Ensure schedule has required fields
        if validatedSchedule.timeOfDay.isEmpty {
            let defaultTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
            validatedSchedule.timeOfDay = [defaultTime]
        }
        
        if validatedSchedule.frequency == .weekly && (validatedSchedule.daysOfWeek == nil || validatedSchedule.daysOfWeek?.isEmpty == true) {
            validatedSchedule.daysOfWeek = [1] // Default to Monday
        }
        
        // Remove any existing schedules for this medicine to avoid duplicates
        medicationSchedules.removeAll { $0.medicineId == schedule.medicineId }
        
        // Add to our collection
        medicationSchedules.append(validatedSchedule)
        
        // Save to persistent storage
        saveSchedules()
        
        // Force rebuild today's doses
        updateTodayDoses()
        
        // Force UI update
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    // Helper method to validate a schedule
    func validateSchedule(_ schedule: MedicationSchedule) -> MedicationSchedule {
        var validSchedule = schedule
        
        // Ensure schedule has required fields
        if validSchedule.timeOfDay.isEmpty {
            print("⚠️ Schedule has no times, adding default")
            let defaultTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
            validSchedule.timeOfDay = [defaultTime]
        }
        
        if validSchedule.frequency == .weekly && (validSchedule.daysOfWeek == nil || validSchedule.daysOfWeek?.isEmpty == true) {
            print("⚠️ Weekly schedule has no days, adding Monday")
            validSchedule.daysOfWeek = [1] // Default to Monday
        }
        
        if validSchedule.frequency == .custom && validSchedule.customInterval == nil {
            print("⚠️ Custom schedule has no interval, setting to daily")
            validSchedule.customInterval = 1
        }
        
        // Safety check on dates
        if validSchedule.startDate > Date().addingTimeInterval(60*60*24*365*10) {
            print("⚠️ Start date too far in future, resetting to today")
            validSchedule.startDate = Date()
        }
        
        if let endDate = validSchedule.endDate, endDate < validSchedule.startDate {
            print("⚠️ End date before start date, removing end date")
            validSchedule.endDate = nil
        }
        
        return validSchedule
    }
    
    // Complete rebuild of all doses
    func rebuildAllDoses() {
        print("🔄 Completely rebuilding all doses")
        
        // Clear existing data
        todayDoses = []
        upcomingDoses = []
        
        // 1. First ensure we have fresh data
        loadSchedules()
        loadDoses()
        
        // 2. Get all active schedules
        let activeSchedules = medicationSchedules.filter { $0.active }
        print("📋 Found \(activeSchedules.count) active schedules")
        
        // 3. Process today's doses
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
                print("⚠️ Warning: Could not find medicine for ID: \(schedule.medicineId)")
            }
        }
        
        // 4. Sort and update
        todayDoses = newTodayDoses.sorted { $0.scheduledTime < $1.scheduledTime }
        print("✅ Today doses rebuilt: \(todayDoses.count) total")
        
        // 5. Process upcoming doses
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
        
        // 6. Sort and limit
        upcomingDoses = newUpcomingDoses.sorted { $0.scheduledTime < $1.scheduledTime }.prefix(5).map { $0 }
        print("✅ Upcoming doses rebuilt: \(upcomingDoses.count) total")
    }
    
    // Direct method to ensure a schedule appears in Today view
    func forceScheduleToAppearInToday(_ schedule: MedicationSchedule) {
        print("Forcing schedule to appear in Today view: \(schedule.medicineName)")
        
        // 1. Add or update the schedule in memory
        if let index = medicationSchedules.firstIndex(where: { $0.id == schedule.id }) {
            medicationSchedules[index] = schedule
        } else {
            medicationSchedules.append(schedule)
        }
        
        // 2. Save to persistent storage
        saveSchedules()
        
        // 3. Clear cache to ensure fresh medicine data
        clearCache()
        
        // 4. Immediately rebuild today's doses
        DispatchQueue.main.async {
            self.rebuildTodayDoses()
            
            // 5. Force UI update
            self.objectWillChange.send()
            
            // 6. Use background thread to save to CoreData
            DispatchQueue.global(qos: .userInitiated).async {
                // Save to CoreData
                let coreDataManager = CoreDataManager(context: self.context)
                coreDataManager.saveSchedule(schedule)
                
                // Reload everything after save
                DispatchQueue.main.async {
                    self.refreshAllData()
                }
            }
        }
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
    
    // Replace your current addSchedule method with this improved version
    // Replace the addSchedule method with this improved version
    func addSchedule(_ schedule: MedicationSchedule) {
        // Validate the schedule before adding it
        let validatedSchedule = validateScheduleBeforeSaving(schedule)
        medicationSchedules.append(validatedSchedule)
        saveSchedules()
        updateTodayDoses()
        updateUpcomingDoses()
        // Use the force save method to ensure schedule shows up
        forceSaveAndShowSchedule(schedule)
    }
    
    func updateSchedule(_ schedule: MedicationSchedule) {
        
        // Validate the schedule before updating
        let validatedSchedule = validateScheduleBeforeSaving(schedule)
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
    
    
    // Replace or add this improved updateTodayDoses method
    func updateTodayDoses() {
        print("🔄 Updating today doses")
        
        // Clear existing today doses
        todayDoses = []
        
        // Get all active schedules
        let activeSchedules = medicationSchedules.filter { $0.active }
        print("📋 Found \(activeSchedules.count) active schedules")
        
        var newTodayDoses: [TodayDose] = []
        
        // For each schedule, get today's dose times
        for schedule in activeSchedules {
            print("Processing schedule: \(schedule.medicineName)")
            let todayTimes = schedule.getTodayDoseTimes()
            print("- Has \(todayTimes.count) doses scheduled for today")
            
            // Check if we have a matching medicine
            if let medicine = getMedicine(byId: schedule.medicineId) {
                for time in todayTimes {
                    // Check if this dose has been recorded
                    let recordedDose = findRecordedDose(forMedicine: schedule.medicineId, around: time)
                    
                    newTodayDoses.append(TodayDose(
                        id: UUID(), // Ensure unique ID
                        medicine: medicine,
                        scheduledTime: time,
                        schedule: schedule,
                        status: recordedDose?.status,
                        doseId: recordedDose?.id
                    ))
                }
            } else {
                print("⚠️ Warning: Could not find medicine for ID: \(schedule.medicineId)")
                
                // Try to load medicines again
                let medicineStore = MedicineStore(context: context)
                medicineStore.loadMedicines()
                
                // Try again to find the medicine
                if let medicine = medicineStore.medicines.first(where: { $0.id == schedule.medicineId }) {
                    print("✅ Found medicine after reloading: \(medicine.name)")
                    
                    // Cache for future use
                    medicineCache[schedule.medicineId] = medicine
                    
                    for time in todayTimes {
                        // Check if this dose has been recorded
                        let recordedDose = findRecordedDose(forMedicine: schedule.medicineId, around: time)
                        
                        newTodayDoses.append(TodayDose(
                            id: UUID(), // Ensure unique ID
                            medicine: medicine,
                            scheduledTime: time,
                            schedule: schedule,
                            status: recordedDose?.status,
                            doseId: recordedDose?.id
                        ))
                    }
                }
            }
        }
        
        // Sort by time
        todayDoses = newTodayDoses.sorted { $0.scheduledTime < $1.scheduledTime }
        print("✅ Updated today doses, new count: \(todayDoses.count)")
        
        // Force UI update
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    // Update updateUpcomingDoses to handle empty times
    func updateUpcomingDoses(forceShow: Bool = false) {
        // Get all active schedules
        let activeSchedules = medicationSchedules.filter { $0.active }
        
        var doses: [UpcomingDose] = []
        
        // For each schedule, create upcoming doses
        for schedule in activeSchedules {
            if let medicine = getMedicine(byId: schedule.medicineId) {
                // If schedule has no times, add a default time
                if schedule.timeOfDay.isEmpty {
                    if forceShow {
                        // Create a time for tomorrow at 9 AM
                        let calendar = Calendar.current
                        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
                        var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
                        components.hour = 9
                        components.minute = 0
                        
                        if let tomorrowNineAM = calendar.date(from: components) {
                            doses.append(UpcomingDose(
                                medicine: medicine,
                                scheduledTime: tomorrowNineAM,
                                schedule: schedule
                            ))
                        }
                    }
                } else {
                    // Use the first time in the schedule to create an upcoming dose
                    let calendar = Calendar.current
                    let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
                    let firstTime = schedule.timeOfDay.first!
                    let timeComponents = calendar.dateComponents([.hour, .minute], from: firstTime)
                    var fullComponents = calendar.dateComponents([.year, .month, .day], from: tomorrow)
                    fullComponents.hour = timeComponents.hour
                    fullComponents.minute = timeComponents.minute
                    
                    if let upcomingTime = calendar.date(from: fullComponents) {
                        doses.append(UpcomingDose(
                            medicine: medicine,
                            scheduledTime: upcomingTime,
                            schedule: schedule
                        ))
                    }
                }
            }
        }
        
        // Sort by time
        upcomingDoses = doses.sorted { $0.scheduledTime < $1.scheduledTime }
        print("✅ Updated upcoming doses, count: \(upcomingDoses.count)")
    }
    
    
    // Call this method when the app starts to ensure all schedules have valid times
    func ensureAllSchedulesHaveValidTimes() {
        print("🔍 Checking all schedules for valid times")
        var hasFixes = false
        
        for (index, schedule) in medicationSchedules.enumerated() {
            if schedule.timeOfDay.isEmpty {
                print("⚠️ Schedule \(schedule.medicineName) has no times defined")
                
                // Create a default time (9 AM)
                let defaultTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
                
                // Create a mutable copy and update it
                var updatedSchedule = schedule
                updatedSchedule.timeOfDay = [defaultTime]
                
                // Update in our array
                medicationSchedules[index] = updatedSchedule
                hasFixes = true
                
                print("✅ Added default 9:00 AM time to schedule")
            }
        }
        
        if hasFixes {
            // Save the fixed schedules
            saveSchedules()
            
            // Refresh UI data
            updateTodayDoses()
            updateUpcomingDoses()
            
            print("✅ Saved fixes for schedules with missing times")
        } else {
            print("✓ All schedules have valid times")
        }
    }
    
    // MARK: - Helper Methods
    
    // Improved getMedicine method with caching and fallback
    func getMedicine(byId id: UUID) -> Medicine? {
        // First check our cache
        if let cached = medicineCache[id] {
            return cached
        }
        
        // Try to get directly from context
        let coreDataManager = CoreDataManager(context: context)
        if let medicine = coreDataManager.fetchMedicine(withId: id) {
            // Cache for future use
            medicineCache[id] = medicine
            return medicine
        }
        
        // If not found, try the MedicineStore
        let medicineStore = MedicineStore(context: context)
        medicineStore.loadMedicines() // Force reload
        
        if let medicine = medicineStore.medicines.first(where: { $0.id == id }) {
            // Cache for future use
            medicineCache[id] = medicine
            return medicine
        }
        
        print("❌ Failed to find medicine with ID: \(id)")
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
