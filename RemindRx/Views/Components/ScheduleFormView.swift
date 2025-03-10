import SwiftUI

struct ScheduleFormView: View {
    @EnvironmentObject var adherenceStore: AdherenceTrackingStore
    @Binding var isPresented: Bool
    
    // For creating a new schedule
    var medicine: Medicine?
    
    // For editing an existing schedule
    var schedule: MedicationSchedule?
    
    // Form state
    @State private var selectedFrequency: MedicationSchedule.Frequency = .daily
    @State private var scheduleTimes: [Date] = [Date()]
    @State private var selectedDays: [Int] = []
    @State private var customInterval: Int = 1
    @State private var startDate: Date = Date()
    @State private var endDate: Date? = nil
    @State private var isActive: Bool = true
    @State private var notes: String = ""
    @State private var hasEndDate: Bool = false
    
    // Alert state
    @State private var showingDiscardAlert = false
    @State private var hasChanges = false
    
    var body: some View {
        Form {
            Section(header: Text("Medicine")) {
                HStack {
                    Text(medicineName)
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(medicineType == .prescription ? "Prescription" : "OTC")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(medicineType == .prescription ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
                        .foregroundColor(medicineType == .prescription ? .blue : .green)
                        .cornerRadius(8)
                }
            }
            
            Section(header: Text("Frequency")) {
                Picker("Schedule Type", selection: $selectedFrequency) {
                    Text("Daily").tag(MedicationSchedule.Frequency.daily)
                    Text("Twice Daily").tag(MedicationSchedule.Frequency.twiceDaily)
                    Text("Three Times Daily").tag(MedicationSchedule.Frequency.threeTimesDaily)
                    Text("Weekly").tag(MedicationSchedule.Frequency.weekly)
                    Text("Custom").tag(MedicationSchedule.Frequency.custom)
                    Text("As Needed").tag(MedicationSchedule.Frequency.asNeeded)
                }
                .pickerStyle(MenuPickerStyle())
                .onChange(of: selectedFrequency) { _ in
                    updateTimesBasedOnFrequency()
                    hasChanges = true
                }
                
                if selectedFrequency == .weekly {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Select Days")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            ForEach(1...7, id: \.self) { day in
                                DayButton(
                                    day: dayName(for: day),
                                    isSelected: selectedDays.contains(day),
                                    action: {
                                        toggleDay(day)
                                        hasChanges = true
                                    }
                                )
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } else if selectedFrequency == .custom {
                    Stepper("Every \(customInterval) day\(customInterval > 1 ? "s" : "")", value: $customInterval, in: 1...31)
                        .onChange(of: customInterval) { _ in
                            hasChanges = true
                        }
                }
            }
            
            if selectedFrequency != .asNeeded {
                Section(header: Text("Times")) {
                    ForEach(0..<scheduleTimes.count, id: \.self) { index in
                        DatePicker(
                            "Time \(index + 1)",
                            selection: Binding(
                                get: { scheduleTimes[index] },
                                set: {
                                    scheduleTimes[index] = $0
                                    hasChanges = true
                                }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(WheelDatePickerStyle())
                    }
                    
                    if canAddMoreTimes {
                        Button(action: {
                            let newTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
                            scheduleTimes.append(newTime)
                            hasChanges = true
                        }) {
                            Label("Add Time", systemImage: "plus.circle")
                        }
                    }
                    
                    if scheduleTimes.count > 1 {
                        Button(action: {
                            scheduleTimes.removeLast()
                            hasChanges = true
                        }) {
                            Label("Remove Time", systemImage: "minus.circle")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            
            Section(header: Text("Duration")) {
                DatePicker(
                    "Start Date",
                    selection: $startDate,
                    displayedComponents: .date
                )
                .onChange(of: startDate) { _ in
                    hasChanges = true
                }
                
                Toggle("Has End Date", isOn: $hasEndDate)
                    .onChange(of: hasEndDate) { value in
                        if !value {
                            endDate = nil
                        } else if endDate == nil {
                            // Set default end date to 30 days from start
                            endDate = Calendar.current.date(byAdding: .day, value: 30, to: startDate)
                        }
                        hasChanges = true
                    }
                
                if hasEndDate, let unwrappedEndDate = endDate {
                    DatePicker(
                        "End Date",
                        selection: Binding(
                            get: { unwrappedEndDate },
                            set: {
                                endDate = $0
                                hasChanges = true
                            }
                        ),
                        in: startDate...,
                        displayedComponents: .date
                    )
                }
                
                Toggle("Active", isOn: $isActive)
                    .onChange(of: isActive) { _ in
                        hasChanges = true
                    }
            }
            
            Section(header: Text("Notes")) {
                TextEditor(text: $notes)
                    .frame(minHeight: 100)
                    .onChange(of: notes) { _ in
                        hasChanges = true
                    }
            }
        }
        .navigationTitle(isEditing ? "Edit Schedule" : "New Schedule")
        .navigationBarItems(
            leading: Button("Cancel") {
                if hasChanges {
                    showingDiscardAlert = true
                } else {
                    isPresented = false
                }
            },
            trailing: Button("Save") {
                saveSchedule()
                isPresented = false
            }
            .disabled(!isFormValid)
        )
        .onAppear {
            loadScheduleData()
        }
        .alert(isPresented: $showingDiscardAlert) {
            Alert(
                title: Text("Discard Changes?"),
                message: Text("You have unsaved changes. Are you sure you want to discard them?"),
                primaryButton: .destructive(Text("Discard")) {
                    isPresented = false
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    // MARK: - Computed Properties
    
    private var isEditing: Bool {
        schedule != nil
    }
    
    private var medicineName: String {
        if let schedule = schedule {
            return schedule.medicineName
        } else if let medicine = medicine {
            return medicine.name
        }
        return "Unknown Medicine"
    }
    
    private var medicineType: Medicine.MedicineType {
        if let schedule = schedule, let medicine = getMedicine(id: schedule.medicineId) {
            return medicine.type
        } else if let medicine = medicine {
            return medicine.type
        }
        return .otc
    }
    
    private var medicineId: UUID {
        if let schedule = schedule {
            return schedule.medicineId
        } else if let medicine = medicine {
            return medicine.id
        }
        fatalError("No medicine ID available")
    }
    
    private var canAddMoreTimes: Bool {
        switch selectedFrequency {
        case .daily:
            return scheduleTimes.count < 4
        case .twiceDaily:
            return scheduleTimes.count < 2
        case .threeTimesDaily:
            return scheduleTimes.count < 3
        case .weekly, .custom:
            return scheduleTimes.count < 4
        case .asNeeded:
            return false
        }
    }
    
    private var isFormValid: Bool {
        // Basic validation
        let hasValidFrequency = selectedFrequency != .weekly || !selectedDays.isEmpty
        let hasValidTimes = selectedFrequency == .asNeeded || !scheduleTimes.isEmpty
        
        return hasValidFrequency && hasValidTimes
    }
    
    // MARK: - Methods
    
    private func getMedicine(id: UUID) -> Medicine? {
        return adherenceStore.getMedicine(byId: id)
    }
    
    private func dayName(for day: Int) -> String {
        let days = ["M", "T", "W", "T", "F", "S", "S"]
        return days[day - 1]
    }
    
    private func toggleDay(_ day: Int) {
        if selectedDays.contains(day) {
            selectedDays.removeAll { $0 == day }
        } else {
            selectedDays.append(day)
        }
    }
    
    private func updateTimesBasedOnFrequency() {
        switch selectedFrequency {
        case .daily:
            if scheduleTimes.isEmpty {
                scheduleTimes = [createTime(hour: 9, minute: 0)]
            } else if scheduleTimes.count > 4 {
                scheduleTimes = Array(scheduleTimes.prefix(4))
            }
        case .twiceDaily:
            if scheduleTimes.isEmpty {
                scheduleTimes = [
                    createTime(hour: 9, minute: 0),
                    createTime(hour: 19, minute: 0)
                ]
            } else if scheduleTimes.count == 1 {
                scheduleTimes.append(createTime(hour: 19, minute: 0))
            } else if scheduleTimes.count > 2 {
                scheduleTimes = Array(scheduleTimes.prefix(2))
            }
        case .threeTimesDaily:
            if scheduleTimes.isEmpty {
                scheduleTimes = [
                    createTime(hour: 9, minute: 0),
                    createTime(hour: 14, minute: 0),
                    createTime(hour: 19, minute: 0)
                ]
            } else if scheduleTimes.count < 3 {
                while scheduleTimes.count < 3 {
                    let hour = scheduleTimes.count * 5 + 9
                    scheduleTimes.append(createTime(hour: hour, minute: 0))
                }
            } else if scheduleTimes.count > 3 {
                scheduleTimes = Array(scheduleTimes.prefix(3))
            }
        case .weekly, .custom:
            if scheduleTimes.isEmpty {
                scheduleTimes = [createTime(hour: 9, minute: 0)]
            }
        case .asNeeded:
            scheduleTimes = []
        }
    }
    
    private func createTime(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? Date()
    }
    
    private func loadScheduleData() {
        // Only load data if we're editing an existing schedule
        guard let schedule = schedule else {
            // If creating new, set some defaults
            updateTimesBasedOnFrequency()
            return
        }
        
        selectedFrequency = schedule.frequency
        
        if !schedule.timeOfDay.isEmpty {
            scheduleTimes = schedule.timeOfDay
        } else {
            updateTimesBasedOnFrequency()
        }
        
        if let days = schedule.daysOfWeek {
            selectedDays = days
        } else if selectedFrequency == .weekly {
            // Default to Monday if no days specified
            selectedDays = [1]
        }
        
        if let interval = schedule.customInterval {
            customInterval = interval
        }
        
        startDate = schedule.startDate
        
        if let scheduleEndDate = schedule.endDate {
            endDate = scheduleEndDate
            hasEndDate = true
        } else {
            hasEndDate = false
        }
        
        isActive = schedule.active
        
        if let scheduleNotes = schedule.notes {
            notes = scheduleNotes
        }
        
        // Reset changes tracking
        hasChanges = false
    }
    
    private func saveSchedule() {
        // Ensure we have at least one time for non-as-needed schedules
        if selectedFrequency != .asNeeded && scheduleTimes.isEmpty {
            updateTimesBasedOnFrequency()
        }
        
        // Make sure your MedicationSchedule initializer matches these parameters
        // This may need to be adjusted to match your exact MedicationSchedule definition
        let newSchedule = MedicationSchedule(
            // Required parameters
            id: schedule?.id ?? UUID(),
            medicineId: medicineId,
            medicineName: medicineName,
            frequency: selectedFrequency,
            timeOfDay: scheduleTimes,
            daysOfWeek: selectedFrequency == .weekly ? selectedDays : nil,
            active: isActive,
            startDate: startDate,
            // Optional parameters - use named parameters if your initializer requires it
            endDate: hasEndDate ? endDate : nil,
            notes: notes.isEmpty ? nil : notes,
            customInterval: selectedFrequency == .custom ? customInterval : nil
            
        )
        
        // Make sure this method exists in your AdherenceTrackingStore
        let validatedSchedule = adherenceStore.validateSchedule(newSchedule)
        
        // Save or update the schedule
        if isEditing {
            adherenceStore.updateSchedule(validatedSchedule)
        } else {
            adherenceStore.addSchedule(validatedSchedule)
        }
        
        // Force rebuild of today's doses
        adherenceStore.refreshAllData()
    }
}

struct DayButton: View {
    let day: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(day)
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(isSelected ? AppColors.primaryFallback() : Color(.systemGray5))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
    }
}
