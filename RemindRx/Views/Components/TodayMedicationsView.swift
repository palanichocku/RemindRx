import SwiftUI

struct TodayMedicationsView: View {
    @ObservedObject var trackingStore: AdherenceTrackingStore
    @EnvironmentObject var medicineStore: MedicineStore
    
    // State for dose recording
    @State private var showingDoseSheet = false
    @State private var selectedSchedule: MedicationSchedule?
    @State private var selectedMedicine: Medicine?
    @State private var selectedTime: Date = Date()
    
    // State for tab selection
    @State private var selectedTab = 0 // 0 = Doses, 1 = Upcoming
    
    // State for tracking doses
    @State private var recordedDoses: [UUID: Bool] = [:]
    
    var body: some View {
        let allMedicines = medicineStore.medicines
        let allSchedules = trackingStore.medicationSchedules
        
        // Log what we found
        print("📊 Medications View Debug")
        print("- Found \(allMedicines.count) medicines")
        print("- Found \(allSchedules.count) schedules")
        
        return VStack(spacing: 0) {
            // Modern tab selector
            ZStack {
                // Background capsule
                Capsule()
                    .fill(Color(.systemGray6))
                    .frame(height: 44)
                    .padding(.horizontal)
                
                // Tab buttons
                HStack(spacing: 0) {
                    // Doses tab
                    Button(action: { withAnimation { selectedTab = 0 } }) {
                        ZStack {
                            if selectedTab == 0 {
                                Capsule()
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                            }
                            
                            HStack(spacing: 6) {
                                Image(systemName: "pills")
                                    .font(.system(size: 15))
                                    .foregroundColor(selectedTab == 0 ? AppColors.primaryFallback() : .gray)
                                
                                Text("Doses")
                                    .fontWeight(selectedTab == 0 ? .semibold : .regular)
                                    .foregroundColor(selectedTab == 0 ? AppColors.primaryFallback() : .gray)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Upcoming tab
                    Button(action: { withAnimation { selectedTab = 1 } }) {
                        ZStack {
                            if selectedTab == 1 {
                                Capsule()
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                            }
                            
                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 15))
                                    .foregroundColor(selectedTab == 1 ? AppColors.primaryFallback() : .gray)
                                
                                Text("Upcoming")
                                    .fontWeight(selectedTab == 1 ? .semibold : .regular)
                                    .foregroundColor(selectedTab == 1 ? AppColors.primaryFallback() : .gray)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            }
            .padding(.vertical, 12)
            
            if allSchedules.isEmpty {
                // No schedules at all
                EmptyStateView(
                    icon: "pills",
                    title: "No Medications Scheduled",
                    message: "Add medication schedules to track your daily doses"
                )
            } else {
                if selectedTab == 0 {
                    // Today's medications (now called Doses)
                    todayView(schedules: allSchedules)
                } else {
                    // Upcoming medications
                    upcomingView(schedules: allSchedules)
                }
            }
        }
        .sheet(isPresented: $showingDoseSheet) {
            // Simple dose recording view
            if let medicine = selectedMedicine, let schedule = selectedSchedule {
                // Create a simple dose object
                let dose = AdherenceTrackingStore.TodayDose(
                    id: UUID(),
                    medicine: medicine,
                    scheduledTime: selectedTime,
                    schedule: schedule,
                    status: nil,
                    doseId: nil
                )
                
                // Show the dose recording view
                DoseRecordingView(
                    dose: dose,
                    isPresented: $showingDoseSheet,
                    trackingStore: trackingStore
                )
                .onDisappear {
                    // Mark this dose as recorded
                    if let doseId = selectedSchedule?.id {
                        recordedDoses[doseId] = true
                    }
                }
            }
        }
        .onAppear {
            // Force refresh on appear
            trackingStore.refreshAllData()
            
            // Check if any doses were already recorded
            updateRecordedDosesState()
        }
    }
    
    // View for today's medications (now called Doses)
    private func todayView(schedules: [MedicationSchedule]) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header for scheduled doses section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Today's Doses")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    // Get schedules for today
                    let todaySchedules = schedules.filter { isScheduleActiveToday($0) }
                    
                    if todaySchedules.isEmpty {
                        EmptyStateView(
                            icon: "calendar.badge.exclamationmark",
                            title: "No Doses Today",
                            message: "You don't have any medications scheduled for today"
                        )
                    } else {
                        ForEach(todaySchedules.indices, id: \.self) { index in
                            let schedule = todaySchedules[index]
                            if let medicine = findMedicine(for: schedule.medicineId) {
                                // Create a modern dose card for each schedule
                                modernDoseCard(
                                    medicine: medicine,
                                    schedule: schedule,
                                    time: getMorningTime(),
                                    isRecorded: recordedDoses[schedule.id, default: false]
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                }
            }
            .padding(.vertical)
        }
    }
    
    // View for upcoming medications (tomorrow)
    private func upcomingView(schedules: [MedicationSchedule]) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header for scheduled doses section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Tomorrow's Schedule")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    // Get schedules for tomorrow
                    let tomorrowSchedules = schedules.filter { isScheduleActiveTomorrow($0) }
                    
                    if tomorrowSchedules.isEmpty {
                        EmptyStateView(
                            icon: "calendar.badge.clock",
                            title: "Nothing Scheduled",
                            message: "You don't have any medications scheduled for tomorrow"
                        )
                    } else {
                        ForEach(tomorrowSchedules.indices, id: \.self) { index in
                            let schedule = tomorrowSchedules[index]
                            if let medicine = findMedicine(for: schedule.medicineId) {
                                // Create modern upcoming dose card for each schedule
                                modernUpcomingCard(
                                    medicine: medicine,
                                    schedule: schedule,
                                    time: getMorningTime()
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                }
            }
            .padding(.vertical)
        }
    }
    
    // Modern dose card with recording status
    private func modernDoseCard(medicine: Medicine, schedule: MedicationSchedule, time: Date, isRecorded: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Medicine info header
            HStack(alignment: .center) {
                // Medicine icon
                ZStack {
                    Circle()
                        .fill(medicine.type == .prescription ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: medicine.type == .prescription ? "pill" : "cross.case")
                        .font(.system(size: 20))
                        .foregroundColor(medicine.type == .prescription ? .blue : .green)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(medicine.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(formatTime(time))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Type badge
                Text(medicine.type.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(medicine.type == .prescription ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
                    .foregroundColor(medicine.type == .prescription ? .blue : .green)
                    .cornerRadius(8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            
            Divider()
                .padding(.leading, 56)
            
            // Action area
            HStack(spacing: 12) {
                Spacer(minLength: 56)
                
                // Check if manufacturer exists and isn't empty
                if !medicine.manufacturer.isEmpty {
                    Text(medicine.manufacturer)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Record status or button
                Group {
                    if isRecorded {
                        // Recorded status
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Recorded")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    } else {
                        // Record button
                        Button(action: {
                            // Set up for the dose recording sheet
                            selectedMedicine = medicine
                            selectedSchedule = schedule
                            selectedTime = time
                            showingDoseSheet = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 8))
                                Text("Record")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(AppColors.primaryFallback())
                            .foregroundColor(.white)
                            .cornerRadius(20)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // Modern upcoming card
    private func modernUpcomingCard(medicine: Medicine, schedule: MedicationSchedule, time: Date) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Medicine info header
            HStack(alignment: .center) {
                // Medicine icon with calendar
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "calendar")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(medicine.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(formatTime(time))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Frequency badge
                Text(getFrequencyText(schedule.frequency))
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            
            Divider()
                .padding(.leading, 56)
            
            // Info area
            HStack(spacing: 12) {
                Spacer(minLength: 56)
                
                // Check if manufacturer exists and isn't empty (fixed conditional binding)
                if !medicine.manufacturer.isEmpty {
                    Text(medicine.manufacturer)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Upcoming status
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 12))
                    Text("Tomorrow")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // Get user-friendly frequency text
    private func getFrequencyText(_ frequency: MedicationSchedule.Frequency) -> String {
        switch frequency {
        case .daily:
            return "Daily"
        case .twiceDaily:
            return "Twice Daily"
        case .threeTimesDaily:
            return "3x Daily"
        case .weekly:
            return "Weekly"
        case .asNeeded:
            return "As Needed"
        case .custom:
            return "Custom"
        }
    }
    
    // Helper to find a medicine by ID
    private func findMedicine(for id: UUID) -> Medicine? {
        if let medicine = medicineStore.medicines.first(where: { $0.id == id }) {
            return medicine
        }
        
        // Log when medicine not found
        print("⚠️ Could not find medicine for ID: \(id)")
        
        // Return nil if not found
        return nil
    }
    
    // Check if a schedule is active today
    private func isScheduleActiveToday(_ schedule: MedicationSchedule) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Check if already expired
        if let endDate = schedule.endDate, calendar.startOfDay(for: endDate) < today {
            print("Schedule \(schedule.medicineName) has ended on \(endDate)")
            return false
        }
        
        // Check frequency
        switch schedule.frequency {
        case .daily, .twiceDaily, .threeTimesDaily:
            return true
            
        case .weekly:
            // Check if today's weekday matches
            if let daysOfWeek = schedule.daysOfWeek {
                let weekday = calendar.component(.weekday, from: today)
                let adjustedWeekday = weekday == 1 ? 7 : weekday - 1 // Convert to 1-7 (Mon-Sun)
                return daysOfWeek.contains(adjustedWeekday)
            }
            return false
            
        case .custom:
            // For custom interval, check if today is a scheduled day
            if let interval = schedule.customInterval,
               let startDay = calendar.ordinality(of: .day, in: .era, for: schedule.startDate),
               let currentDay = calendar.ordinality(of: .day, in: .era, for: today) {
                
                let daysSinceStart = currentDay - startDay
                return daysSinceStart >= 0 && daysSinceStart % interval == 0
            }
            return false
            
        case .asNeeded:
            return true
        }
    }
    
    // Check if a schedule is active tomorrow
    private func isScheduleActiveTomorrow(_ schedule: MedicationSchedule) -> Bool {
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) else {
            return false
        }
        let tomorrowStart = calendar.startOfDay(for: tomorrow)
        
        // Check if already expired by tomorrow
        if let endDate = schedule.endDate, calendar.startOfDay(for: endDate) < tomorrowStart {
            print("Schedule \(schedule.medicineName) will end before tomorrow")
            return false
        }
        
        // Check frequency
        switch schedule.frequency {
        case .daily, .twiceDaily, .threeTimesDaily:
            return true
            
        case .weekly:
            // Check if tomorrow's weekday matches
            if let daysOfWeek = schedule.daysOfWeek {
                let weekday = calendar.component(.weekday, from: tomorrow)
                let adjustedWeekday = weekday == 1 ? 7 : weekday - 1 // Convert to 1-7 (Mon-Sun)
                return daysOfWeek.contains(adjustedWeekday)
            }
            return false
            
        case .custom:
            // For custom interval, check if tomorrow is a scheduled day
            if let interval = schedule.customInterval,
               let startDay = calendar.ordinality(of: .day, in: .era, for: schedule.startDate),
               let tomorrowDay = calendar.ordinality(of: .day, in: .era, for: tomorrow) {
                
                let daysSinceStart = tomorrowDay - startDay
                return daysSinceStart >= 0 && daysSinceStart % interval == 0
            }
            return false
            
        case .asNeeded:
            return true
        }
    }
    
    // Default 9 AM time for all doses
    private func getMorningTime() -> Date {
        let calendar = Calendar.current
        let morning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
        return morning
    }
    
    // Formats time for display
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Update recorded doses state based on trackingStore data
    private func updateRecordedDosesState() {
        print("📊 Checking recorded doses state")
        print("- Found \(trackingStore.medicationDoses.count) doses in tracking store")
        
        // Check each schedule to see if it has been recorded today
        for schedule in trackingStore.medicationSchedules {
            let doseForToday = trackingStore.medicationDoses.first { dose in
                dose.medicineId == schedule.medicineId &&
                Calendar.current.isDateInToday(dose.timestamp) &&
                dose.taken
            }
            
            if doseForToday != nil {
                print("- Found recorded dose for \(schedule.medicineName)")
                recordedDoses[schedule.id] = true
            }
        }
    }
}
