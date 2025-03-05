import SwiftUI
import Combine

struct SimpleScheduleCreationView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var trackingStore: AdherenceTrackingStore
    
    let medicine: Medicine
    var onComplete: () -> Void
    
    // State for schedule properties
    @State private var frequency = MedicationSchedule.Frequency.daily
    @State private var selectedTimes: [Date] = []
    @State private var daysOfWeek: [Int] = [1, 2, 3, 4, 5]  // Mon-Fri by default
    @State private var customInterval = 1
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(60*60*24*30*3)  // 3 months from now
    @State private var useEndDate = false
    @State private var notes = ""
    
    // UI state
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isSuccessAlert = false
    
    // Debug state
    @State private var debugInfo = ""
    
    var body: some View {
        ZStack {
            // Main scroll view for form
            ScrollView {
                VStack(spacing: 20) {
                    // Medicine info header
                    medicineInfoSection
                    
                    // Frequency selection
                    frequencySection
                    
                    // Time selection
                    timesSection
                    
                    // Date range
                    dateRangeSection
                    
                    // Notes
                    notesSection
                    
                    // Actions
                    Button(action: createSchedule) {
                        Text("Save Schedule")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.vertical, 14)
                            .background(AppColors.primaryFallback())
                            .cornerRadius(10)
                    }
                    .padding(.top)
                    .padding(.bottom, 40)
                    
                    // Debug info (in development builds only)
                    #if DEBUG
                    if !debugInfo.isEmpty {
                        Text(debugInfo)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    #endif
                }
                .padding()
            }
            .navigationTitle("Add Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            
            // Loading overlay
            if isLoading {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    ProgressView()
                    Text("Creating schedule...")
                        .padding(.top, 8)
                        .foregroundColor(.white)
                }
                .padding(20)
                .background(Color.gray.opacity(0.7))
                .cornerRadius(10)
            }
        }
        .alert(isPresented: $showAlert) {
            if isSuccessAlert {
                return Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK")) {
                        // After success, go back to the previous screen
                        onComplete()
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            } else {
                return Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .onAppear {
            initializeTimes()
            debugInfo = "Medicine ID: \(medicine.id)\nName: \(medicine.name)\nLoaded at: \(Date().formatted(date: .abbreviated, time: .standard))"
        }
    }
    
    // MARK: - UI Sections
    
    private var medicineInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Medicine")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(medicine.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    if !medicine.manufacturer.isEmpty {
                        Text(medicine.manufacturer)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: medicine.type == .prescription ? "pills.fill" : "cross.case.fill")
                    .foregroundColor(medicine.type == .prescription ? .blue : .green)
                    .font(.title2)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
    
    private var frequencySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Frequency")
                .font(.headline)
            
            VStack(spacing: 12) {
                Picker("Frequency", selection: $frequency) {
                    Text("Daily").tag(MedicationSchedule.Frequency.daily)
                    Text("Twice Daily").tag(MedicationSchedule.Frequency.twiceDaily)
                    Text("Weekly").tag(MedicationSchedule.Frequency.weekly)
                    Text("As Needed").tag(MedicationSchedule.Frequency.asNeeded)
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: frequency) { _ in
                    initializeTimes()
                }
                
                if frequency == .weekly {
                    weekdayPickerView
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
    
    private var timesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Times")
                .font(.headline)
            
            VStack(spacing: 12) {
                ForEach(0..<getTimesCount(), id: \.self) { index in
                    HStack {
                        Text(getTimeLabel(index))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        DatePicker("", selection: binding(for: index), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
    
    private var weekdayPickerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Days of Week")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                ForEach(0..<7, id: \.self) { index in
                    let day = index + 1 // 1-7 for Monday-Sunday
                    let label = ["M", "T", "W", "T", "F", "S", "S"][index]
                    let isSelected = daysOfWeek.contains(day)
                    
                    Button(action: {
                        toggleDay(day)
                    }) {
                        Text(label)
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 30, height: 30)
                            .background(isSelected ? AppColors.primaryFallback() : Color(.systemGray5))
                            .foregroundColor(isSelected ? .white : .primary)
                            .clipShape(Circle())
                    }
                }
            }
        }
    }
    
    private var dateRangeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date Range")
                .font(.headline)
            
            VStack(spacing: 15) {
                DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                
                Toggle("Set End Date", isOn: $useEndDate)
                
                if useEndDate {
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headline)
            
            TextField("Optional notes", text: $notes)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
        }
    }
    
    // MARK: - Helper Methods
    
    private func getTimesCount() -> Int {
        switch frequency {
        case .daily, .weekly, .asNeeded, .custom:
            return 1
        case .twiceDaily:
            return 2
        case .threeTimesDaily:
            return 3
        }
    }
    
    private func binding(for index: Int) -> Binding<Date> {
        return Binding(
            get: {
                // Handle out of range gracefully
                guard index < selectedTimes.count else {
                    return Date()
                }
                return selectedTimes[index]
            },
            set: { newValue in
                // Expand array if needed
                while selectedTimes.count <= index {
                    selectedTimes.append(Date())
                }
                selectedTimes[index] = newValue
            }
        )
    }
    
    private func getTimeLabel(_ index: Int) -> String {
        if getTimesCount() == 1 {
            return "Time"
        }
        
        switch index {
        case 0:
            return "Morning"
        case 1:
            return "Evening"
        case 2:
            return "Night"
        default:
            return "Time \(index + 1)"
        }
    }
    
    private func toggleDay(_ day: Int) {
        if daysOfWeek.contains(day) {
            // Only remove if we have more than one day selected
            if daysOfWeek.count > 1 {
                daysOfWeek.removeAll { $0 == day }
            }
        } else {
            daysOfWeek.append(day)
        }
        
        // Keep sorted
        daysOfWeek.sort()
    }
    
    private func initializeTimes() {
        // Set default times based on frequency
        let calendar = Calendar.current
        
        switch frequency {
        case .daily, .weekly, .asNeeded, .custom:
            // 9 AM
            let morningTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
            selectedTimes = [morningTime]
            
        case .twiceDaily:
            // 9 AM and 6 PM
            let morningTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
            let eveningTime = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
            selectedTimes = [morningTime, eveningTime]
            
        case .threeTimesDaily:
            // 9 AM, 2 PM, and 9 PM
            let morningTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
            let afternoonTime = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: Date()) ?? Date()
            let eveningTime = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: Date()) ?? Date()
            selectedTimes = [morningTime, afternoonTime, eveningTime]
        }
    }
    
    // Replace the createSchedule() method with this better version:
    private func createSchedule() {
        // Validate form
        guard !selectedTimes.isEmpty else {
            showError(title: "Missing Times", message: "Please set at least one time for the schedule.")
            return
        }
        
        if frequency == .weekly && daysOfWeek.isEmpty {
            showError(title: "Missing Days", message: "Please select at least one day of the week.")
            return
        }
        
        if useEndDate && endDate < startDate {
            showError(title: "Invalid Date Range", message: "End date cannot be before start date.")
            return
        }
        
        // Show loading
        isLoading = true
        
        // Create the schedule with a slight delay to allow UI to update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            do {
                // Create schedule object
                let schedule = MedicationSchedule(
                    id: UUID(),
                    medicineId: self.medicine.id,
                    medicineName: self.medicine.name,
                    frequency: self.frequency,
                    timeOfDay: self.selectedTimes,
                    daysOfWeek: self.frequency == .weekly ? self.daysOfWeek : nil,
                    active: true,
                    startDate: self.startDate,
                    endDate: self.useEndDate ? self.endDate : nil,
                    notes: self.notes.isEmpty ? nil : self.notes,
                    customInterval: self.frequency == .custom ? self.customInterval : nil
                )
                
                print("📝 Creating schedule: \(schedule.medicineName) (ID: \(schedule.id))")
                print("📝 Medicine ID: \(schedule.medicineId)")
                print("📝 Frequency: \(schedule.frequency.rawValue)")
                print("📝 Times count: \(schedule.timeOfDay.count)")
                
                // Just use the standard method and ensure it's properly implemented
                print("Adding schedule")
                self.trackingStore.addSchedule(schedule)
                
                // Force a rebuild of today's doses to ensure the schedule appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    print("Forcing data refresh")
                    self.trackingStore.refreshAllData()
                    
                    // Also force a UI update
                    DispatchQueue.main.async {
                        self.trackingStore.objectWillChange.send()
                    }
                }
                
                // Show success and dismiss
                self.isLoading = false
                self.showSuccess(title: "Schedule Created", message: "Your medication schedule has been created successfully.")
                
            } catch {
                // Show error
                self.isLoading = false
                self.showError(title: "Schedule Error", message: "Failed to create schedule: \(error.localizedDescription)")
            }
        }
    }
    
    
    private func showError(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        isSuccessAlert = false
        showAlert = true
    }
    
    private func showSuccess(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        isSuccessAlert = true
        showAlert = true
    }
}
