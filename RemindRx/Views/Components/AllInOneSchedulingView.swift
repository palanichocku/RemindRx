//
//  AllInOneSchedulingView.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/5/25.
//

import SwiftUI
import Combine

/// This view handles both medicine selection and schedule creation in a single view
/// to avoid navigation issues
struct AllInOneSchedulingView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var medicineStore: MedicineStore
    @ObservedObject var trackingStore: AdherenceTrackingStore
    
    // View state
    @State private var selectedMedicineId: UUID?
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showSuccessAlert = false
    
    // Schedule settings - will only be used after medicine selection
    @State private var frequency = MedicationSchedule.Frequency.daily
    @State private var selectedTimes: [Date] = []
    @State private var daysOfWeek: [Int] = [1, 2, 3, 4, 5]  // Mon-Fri by default
    @State private var customInterval = 1
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(60*60*24*30*3)  // 3 months from now
    @State private var useEndDate = false
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            Group {
                if selectedMedicineId == nil {
                    // Step 1: Medicine selection
                    medicineSelectionView
                } else {
                    // Step 2: Schedule creation
                    scheduleCreationView
                }
            }
            .navigationTitle(selectedMedicineId == nil ? "Select Medicine" : "Create Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .overlay {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.4)
                            .edgesIgnoringSafeArea(.all)
                        
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Please wait...")
                                .foregroundColor(.white)
                        }
                        .padding(25)
                        .background(Color(.systemGray).opacity(0.7))
                        .cornerRadius(10)
                    }
                }
            }
        }
        .onAppear {
            initializeTimes()
        }
        .alert(isPresented: $showAlert) {
            if showSuccessAlert {
                return Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK")) {
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
    }
    
    // View for selecting a medicine
    private var medicineSelectionView: some View {
        List {
            if medicineStore.medicines.isEmpty {
                Text("No medicines available")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                // Filter to only show medicines without schedules
                let availableMedicines = medicineStore.medicines.filter { medicine in
                    !trackingStore.hasSchedule(for: medicine.id)
                }
                
                if availableMedicines.isEmpty {
                    Text("All medicines already have schedules")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(availableMedicines) { medicine in
                        Button(action: {
                            selectMedicine(medicine)
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(medicine.name)
                                        .font(.headline)
                                    
                                    if !medicine.manufacturer.isEmpty {
                                        Text(medicine.manufacturer)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    // View for creating a schedule
    private var scheduleCreationView: some View {
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
            }
            .padding()
        }
    }
    
    // Medicine info section
    private var medicineInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Medicine")
                .font(.headline)
            
            if let medicineId = selectedMedicineId, let medicine = getMedicine(for: medicineId) {
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
            } else {
                Text("Select a medicine first")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            }
        }
    }
    
    // Frequency section
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
    
    // Times section
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
    
    // Date range section
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
    
    // Notes section
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
    
    // Weekday picker
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
    
    // MARK: - Helper methods
    
    private func selectMedicine(_ medicine: Medicine) {
        print("Selected medicine: \(medicine.name) (ID: \(medicine.id))")
        selectedMedicineId = medicine.id
    }
    
    private func getMedicine(for id: UUID) -> Medicine? {
        return medicineStore.medicines.first { $0.id == id }
    }
    
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
    
    private func createSchedule() {
        guard let medicineId = selectedMedicineId, let medicine = getMedicine(for: medicineId) else {
            showAlert(title: "Error", message: "No medicine selected", isSuccess: false)
            return
        }
        
        // Validate form
        guard !selectedTimes.isEmpty else {
            showAlert(title: "Missing Times", message: "Please set at least one time for the schedule.", isSuccess: false)
            return
        }
        
        if frequency == .weekly && daysOfWeek.isEmpty {
            showAlert(title: "Missing Days", message: "Please select at least one day of the week.", isSuccess: false)
            return
        }
        
        if useEndDate && endDate < startDate {
            showAlert(title: "Invalid Date Range", message: "End date cannot be before start date.", isSuccess: false)
            return
        }
        
        // Show loading
        isLoading = true
        
        // Create the schedule with a slight delay to allow UI to update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Use yesterday as the default start date to ensure it appears today
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            
            // Create schedule object
            let schedule = MedicationSchedule(
                id: UUID(),
                medicineId: medicine.id,
                medicineName: medicine.name,
                frequency: self.frequency,
                timeOfDay: self.selectedTimes,
                daysOfWeek: self.frequency == .weekly ? self.daysOfWeek : nil,
                active: true,
                startDate: yesterday, // IMPORTANT: Use yesterday instead of self.startDate
                endDate: self.useEndDate ? self.endDate : nil,
                notes: self.notes.isEmpty ? nil : self.notes,
                customInterval: self.frequency == .custom ? self.customInterval : nil
            )
            
            print("📝 Creating schedule: \(schedule.medicineName) (ID: \(schedule.id))")
            print("📝 Medicine ID: \(schedule.medicineId)")
            print("📝 Frequency: \(schedule.frequency.rawValue)")
            print("📝 Times count: \(schedule.timeOfDay.count)")
            print("📝 Start date: \(yesterday)")
            
            // Save schedule
            print("Adding schedule")
            self.trackingStore.addSchedule(schedule)
            
            // Also save directly to Core Data for redundancy
            print("Saving to Core Data directly")
            CoreDataManager(context: self.trackingStore.context).saveSchedule(schedule)
            
            // Force schedules to show in Today tab - use a safer approach
            print("Trying to force schedules to show in Today tab")
            // Call refreshAllData which will internally call our force method if it exists
            self.trackingStore.refreshAllData()

            // Add a redundant direct call to updateTodayDoses as a fallback
            DispatchQueue.main.async {
                print("Also updating today doses directly")
                self.trackingStore.updateTodayDoses()
            }
            
            // Force a refresh of all data
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                print("Forcing data refresh")
                self.trackingStore.refreshAllData()
                
                // Hide loading and show success
                self.isLoading = false
                self.showAlert(
                    title: "Schedule Created",
                    message: "Your medication schedule has been created successfully.",
                    isSuccess: true
                )
            }
        }
    }

    
    private func showAlert(title: String, message: String, isSuccess: Bool) {
        alertTitle = title
        alertMessage = message
        showSuccessAlert = isSuccess
        showAlert = true
    }
}
