import SwiftUI

struct AdherenceHistoryView: View {
    @ObservedObject var trackingStore: AdherenceTrackingStore
    @EnvironmentObject var medicineStore: MedicineStore
    @State private var selectedMedicineId: UUID?
    @State private var showingFullHistory = false
    @State private var timeRange = 7 // days
    @State private var showingMedicinePicker = false
    
    // Only show medicines that have schedules
    var availableMedicines: [Medicine] {
        let medicinesWithSchedules = Set(trackingStore.medicationSchedules.map { $0.medicineId })
        return medicineStore.medicines.filter { medicinesWithSchedules.contains($0.id) }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if availableMedicines.isEmpty {
                    // Show empty state when no medicines with schedules
                    EmptyStateView(
                        icon: "chart.xyaxis.line",
                        title: "No Medication History",
                        message: "Add medicine schedules first to track adherence history"
                    )
                    .padding(.top, 40)
                } else {
                    // Medicine dropdown selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Select Medicine")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        // Dropdown menu
                        Button(action: {
                            showingMedicinePicker = true
                        }) {
                            HStack {
                                if let selectedId = selectedMedicineId,
                                   let medicine = availableMedicines.first(where: { $0.id == selectedId }) {
                                    Text(medicine.name)
                                        .fontWeight(.medium)
                                } else {
                                    Text("Select a medicine")
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        .actionSheet(isPresented: $showingMedicinePicker) {
                            ActionSheet(
                                title: Text("Select Medicine"),
                                buttons: availableMedicines.map { medicine in
                                    .default(Text(medicine.name)) {
                                        selectedMedicineId = medicine.id
                                    }
                                } + [.cancel()]
                            )
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 5)
                    
                    // Time range selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Time Range")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Picker("", selection: $timeRange) {
                            Text("7 Days").tag(7)
                            Text("14 Days").tag(14)
                            Text("30 Days").tag(30)
                            Text("90 Days").tag(90)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                    }
                    
                    if let selectedId = selectedMedicineId,
                       let medicine = availableMedicines.first(where: { $0.id == selectedId }) {
                        
                        Divider()
                            .padding(.vertical, 5)
                        
                        // Adherence stats
                        VStack(spacing: 15) {
                            // Calculate real statistics for the selected medicine
                            let stats = calculateStats(medicineId: selectedId)
                            
                            // Adherence rate
                            statsCard(
                                title: "Adherence Rate",
                                value: String(format: "%.1f%%", stats.adherenceRate),
                                icon: "chart.bar.fill",
                                color: .blue
                            )
                            
                            // Current streak
                            statsCard(
                                title: "Current Streak",
                                value: "\(stats.currentStreak) days",
                                icon: "flame.fill",
                                color: .orange
                            )
                            
                            // Doses taken
                            statsCard(
                                title: "Doses Taken",
                                value: "\(stats.dosesTaken)",
                                icon: "checkmark.circle.fill",
                                color: .green
                            )
                            
                            // View full history button
                            Button(action: {
                                showingFullHistory = true
                            }) {
                                Text("View Detailed History")
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColors.primaryFallback())
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                            }
                            .padding(.horizontal)
                        }
                    } else {
                        EmptyStateView(
                            icon: "chart.xyaxis.line",
                            title: "Select a Medicine",
                            message: "Choose a medicine to see adherence stats"
                        )
                        .padding(.top, 40)
                    }
                }
            }
            .padding(.vertical)
            .onAppear {
                // Select first medicine by default if none selected
                if selectedMedicineId == nil && !availableMedicines.isEmpty {
                    selectedMedicineId = availableMedicines.first?.id
                }
                
                // Debug
                print("🔍 History view: Found \(availableMedicines.count) medicines with schedules")
                print("🔍 Recorded doses: \(trackingStore.medicationDoses.count)")
                
                // Refresh data when view appears
                trackingStore.refreshAllData()
            }
            .sheet(isPresented: $showingFullHistory) {
                if let selectedId = selectedMedicineId,
                   let medicine = availableMedicines.first(where: { $0.id == selectedId }) {
                    
                    NavigationView {
                        HistoryDetailView(
                            medicine: medicine,
                            timeRange: timeRange,
                            trackingStore: trackingStore
                        )
                        .navigationTitle("Medication History")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Close") {
                                    showingFullHistory = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Stats card view
    private func statsCard(title: String, value: String, icon: String, color: Color) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Spacer()
            
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(color)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    // Calculate accurate statistics for a medicine
    private func calculateStats(medicineId: UUID) -> (adherenceRate: Double, currentStreak: Int, dosesTaken: Int) {
        // Count doses taken
        let dosesTaken = trackingStore.medicationDoses.filter {
            $0.medicineId == medicineId && $0.taken
        }.count
        
        // If no doses taken, everything should be zero
        if dosesTaken == 0 {
            return (0.0, 0, 0)
        }
        
        // Calculate adherence rate - compare taken doses vs expected doses
        var adherenceRate = 0.0
        
        // Get schedules for this medicine
        let schedules = trackingStore.medicationSchedules.filter { $0.medicineId == medicineId }
        if !schedules.isEmpty {
            // Calculate expected doses based on schedule
            let calendar = Calendar.current
            let endDate = Date()
            let startDate = calendar.date(byAdding: .day, value: -timeRange, to: endDate) ?? Date()
            
            var expectedDoses = 0
            var currentDate = startDate
            
            while currentDate <= endDate {
                for schedule in schedules {
                    // Skip if schedule wasn't active on this date
                    if currentDate < schedule.startDate ||
                        (schedule.endDate != nil && currentDate > schedule.endDate!) {
                        continue
                    }
                    
                    // Count expected doses based on frequency
                    let doseTimes = getDoseTimesForDay(schedule: schedule, date: currentDate)
                    expectedDoses += doseTimes.count
                }
                
                // Move to next day
                if let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) {
                    currentDate = nextDate
                } else {
                    break
                }
            }
            
            // Calculate adherence rate
            adherenceRate = expectedDoses > 0 ? (Double(dosesTaken) / Double(expectedDoses)) * 100.0 : 0.0
        }
        
        // Calculate current streak - only count if dose taken
        var currentStreak = 0
        if dosesTaken > 0 {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            var dayToCheck = today
            
            while true {
                let dayStart = calendar.startOfDay(for: dayToCheck)
                let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart)!
                
                // Get doses for this day
                let dayDoses = trackingStore.medicationDoses.filter {
                    $0.medicineId == medicineId &&
                    calendar.isDate($0.timestamp, inSameDayAs: dayToCheck)
                }
                
                // Get taken doses
                let takenDoses = dayDoses.filter { $0.taken }
                
                // If no taken doses, break streak
                if takenDoses.isEmpty {
                    break
                }
                
                // Get scheduled doses for this day
                var expectedDoses = 0
                for schedule in schedules {
                    let doseTimes = getDoseTimesForDay(schedule: schedule, date: dayToCheck)
                    expectedDoses += doseTimes.count
                }
                
                // If expected doses > 0 but not all taken, break streak
                if expectedDoses > 0 && takenDoses.count < expectedDoses {
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
        }
        
        print("📊 Stats for medicine \(medicineId):")
        print("- Doses taken: \(dosesTaken)")
        print("- Streak: \(currentStreak)")
        print("- Adherence rate: \(adherenceRate)%")
        
        return (adherenceRate, currentStreak, dosesTaken)
    }
    
    // Helper to get dose times for a specific day based on schedule
    private func getDoseTimesForDay(schedule: MedicationSchedule, date: Date) -> [Date] {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        var doseTimes: [Date] = []
        
        // Skip if schedule wasn't active on this date
        if date < schedule.startDate || (schedule.endDate != nil && date > schedule.endDate!) {
            return []
        }
        
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
            let adjustedWeekday = weekday == 1 ? 7 : weekday - 1 // Convert to 1-7 (Mon-Sun)
            
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
                if daysSinceStart >= 0 && daysSinceStart % interval == 0 {
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
}
