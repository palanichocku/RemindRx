import SwiftUI

struct MedicationTrackingView: View {
    @EnvironmentObject var medicineStore: MedicineStore
    @EnvironmentObject var adherenceStore: AdherenceTrackingStore
    
    @State private var selectedTab = 0
    @State private var isLoading = true
    @State private var showAddScheduleSheet = false
    @State private var showDoseRecordingSheet = false
    @State private var selectedDose: AdherenceTrackingStore.TodayDose? = nil
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Tab selector
                customTabSelector
                
                // Content based on selected tab
                if isLoading {
                    loadingView
                } else {
                    tabContent
                }
            }
            
            // Sheet for recording doses
            .sheet(isPresented: $showDoseRecordingSheet) {
                if let dose = selectedDose {
                    NavigationView {
                        DoseRecordingView(
                            dose: dose,
                            isPresented: $showDoseRecordingSheet,
                            trackingStore: adherenceStore
                        )
                    }
                }
            }
            
            // Sheet for adding schedules
            .sheet(isPresented: $showAddScheduleSheet) {
                NavigationView {
                    AllInOneSchedulingView(trackingStore: adherenceStore)
                        .environmentObject(medicineStore)
                }
            }
        }
        .navigationTitle("Medication Tracking")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if selectedTab == 1 { // Only show add button in Schedule tab
                    Button(action: {
                        showAddScheduleSheet = true
                    }) {
                        Image(systemName: "plus.circle")
                    }
                }
            }
        }
        .onAppear {
            // Load data when view appears with a short delay to allow UI to render
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                refreshData()
            }
        }
    }
    
    // MARK: - Component Views
    
    private var customTabSelector: some View {
        HStack(spacing: 0) {
            // Today tab
            tabButton(title: "Today", index: 0)
            
            // Schedule tab
            tabButton(title: "Schedules", index: 1)
            
            // History tab
            tabButton(title: "History", index: 2)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    private func tabButton(title: String, index: Int) -> some View {
        Button(action: {
            withAnimation {
                selectedTab = index
                refreshData() // Refresh data when tab changes
            }
        }) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 16))
                    .fontWeight(selectedTab == index ? .semibold : .regular)
                    .foregroundColor(selectedTab == index ? AppColors.primaryFallback() : .gray)
                    .padding(.horizontal, 16)
                
                // Indicator bar
                Rectangle()
                    .fill(selectedTab == index ? AppColors.primaryFallback() : Color.clear)
                    .frame(height: 3)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private var loadingView: some View {
        //var message: String = "Loading..." // Default message parameter
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading medication data...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var tabContent: some View {
        Group {
            switch selectedTab {
            case 0:
                todayDosesView
            case 1:
                schedulesView
            case 2:
                historyView
            default:
                EmptyView()
            }
        }
    }
    
    // MARK: - Tab Views
    
    // Today's doses tab
    private var todayDosesView: some View {
        ScrollView {
            VStack(spacing: 15) {
                // Summary card
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today's Doses")
                            .font(.headline)
                        
                        Text("\(adherenceStore.todayDoses.count) doses scheduled")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Status summary
                    HStack(spacing: 12) {
                        statusCounter(
                            count: adherenceStore.todayDoses.filter { $0.status == .taken }.count,
                            title: "Taken",
                            color: .green
                        )
                        
                        statusCounter(
                            count: adherenceStore.todayDoses.filter { $0.status == nil }.count,
                            title: "Due",
                            color: .blue
                        )
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 10)
                
                if adherenceStore.todayDoses.isEmpty {
                    // No doses today
                    noDosesView
                } else {
                    // Today's doses list
                    VStack(spacing: 12) {
                        ForEach(adherenceStore.todayDoses) { dose in
                            todayDoseCard(dose: dose)
                                .onTapGesture {
                                    selectedDose = dose
                                    showDoseRecordingSheet = true
                                }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // Schedules tab
    private var schedulesView: some View {
        ScrollView {
            VStack(spacing: 15) {
                if adherenceStore.medicationSchedules.isEmpty {
                    // No schedules
                    noSchedulesView
                } else {
                    // Schedules list
                    VStack(spacing: 12) {
                        ForEach(adherenceStore.medicationSchedules) { schedule in
                            scheduleCard(schedule: schedule)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                }
            }
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // History tab
    private var historyView: some View {
        // Placeholder for history tab - implement as needed
        Text("History View")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Supporting Views
    
    private func statusCounter(count: Int, title: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.headline)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var noDosesView: some View {
        VStack(spacing: 20) {
            Image(systemName: "pills.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Doses Scheduled Today")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("Add medication schedules to track your daily doses")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                showAddScheduleSheet = true
            }) {
                Text("Add Schedule")
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppColors.primaryFallback())
                    .cornerRadius(8)
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
    }
    
    private var noSchedulesView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Medication Schedules")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("Add medication schedules to track when to take your medicines")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                showAddScheduleSheet = true
            }) {
                Text("Add Schedule")
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppColors.primaryFallback())
                    .cornerRadius(8)
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
    }
    
    private func todayDoseCard(dose: AdherenceTrackingStore.TodayDose) -> some View {
        HStack {
            // Medicine icon
            ZStack {
                Circle()
                    .fill(dose.medicine.type == .prescription ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: dose.medicine.type == .prescription ? "pill" : "cross.case")
                    .font(.system(size: 20))
                    .foregroundColor(dose.medicine.type == .prescription ? .blue : .green)
            }
            
            // Medicine details
            VStack(alignment: .leading, spacing: 2) {
                Text(dose.medicine.name)
                    .font(.headline)
                
                Text(formatTime(dose.scheduledTime))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 8)
            
            Spacer()
            
            // Status indicator
            if let status = dose.status {
                doseStatusBadge(status: status)
            } else {
                Button(action: {
                    selectedDose = dose
                    showDoseRecordingSheet = true
                }) {
                    Text("Record")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppColors.primaryFallback())
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func doseStatusBadge(status: MedicationDose.DoseStatus) -> some View {
        HStack(spacing: 4) {
            switch status {
            case .taken:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Taken")
                    .font(.subheadline)
                    .foregroundColor(.green)
            case .missed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text("Missed")
                    .font(.subheadline)
                    .foregroundColor(.red)
            case .skipped:
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.orange)
                Text("Skipped")
                    .font(.subheadline)
                    .foregroundColor(.orange)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Group {
                switch status {
                case .taken: Color.green.opacity(0.1)
                case .missed: Color.red.opacity(0.1)
                case .skipped: Color.orange.opacity(0.1)
                }
            }
        )
        .cornerRadius(8)
    }
    
    private func scheduleCard(schedule: MedicationSchedule) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with active status
            HStack {
                Text(schedule.medicineName)
                    .font(.headline)
                
                Spacer()
                
                if schedule.active {
                    Text("Active")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                } else {
                    Text("Inactive")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.gray)
                        .cornerRadius(8)
                }
            }
            
            Divider()
            
            // Schedule details
            HStack {
                // Frequency
                VStack(alignment: .leading, spacing: 4) {
                    Text("Frequency")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(schedule.frequency.rawValue)
                        .font(.subheadline)
                }
                
                Spacer()
                
                // Times
                VStack(alignment: .leading, spacing: 4) {
                    Text("Times")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatTimesText(schedule.timeOfDay))
                        .font(.subheadline)
                }
                
                Spacer()
                
                // Edit button
                Button(action: {
                    // Edit schedule functionality
                }) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            
            // Weekly days display if applicable
            if schedule.frequency == .weekly, let days = schedule.daysOfWeek, !days.isEmpty {
                HStack {
                    Text("Days:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatWeekdays(days))
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Helper Methods
    
    private func refreshData() {
        isLoading = true
        
        // Ensure both stores are updated
        medicineStore.loadMedicines()
        
        // IMPORTANT FIX: This ensures that schedules are properly loaded and displayed
        adherenceStore.refreshAllData() // This includes loading schedules and rebuilding doses
        
        // Add a custom fix to ensure that schedules always show their doses for today
        adherenceStore.forceSchedulesToShowToday()
        
        // Delay hiding the loading screen to ensure data is processed
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isLoading = false
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatTimesText(_ times: [Date]) -> String {
        if times.isEmpty {
            return "None"
        }
        
        if times.count == 1 {
            return formatTime(times[0])
        }
        
        return "\(times.count) times"
    }
    
    private func formatWeekdays(_ days: [Int]) -> String {
        let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        
        return days.sorted().map { day in
            let index = max(0, min(day - 1, 6))
            return dayNames[index]
        }.joined(separator: ", ")
    }
}

// MARK: - DoseRecordingView

struct DoseRecordingView: View {
    let dose: AdherenceTrackingStore.TodayDose
    @Binding var isPresented: Bool
    @ObservedObject var trackingStore: AdherenceTrackingStore
    
    @State private var recordAsTaken: Bool = true
    @State private var skippedReason: String = ""
    @State private var notes: String = ""
    @State private var isSaving: Bool = false
    
    var body: some View {
        Form {
            Section(header: Text("Medication")) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dose.medicine.name)
                        .font(.headline)
                    
                    if !dose.medicine.manufacturer.isEmpty {
                        Text(dose.medicine.manufacturer)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
                
                HStack {
                    Text("Scheduled time:")
                    Spacer()
                    Text(formatTime(dose.scheduledTime))
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Record Status")) {
                Picker("Status", selection: $recordAsTaken) {
                    Text("Taken").tag(true)
                    Text("Skipped").tag(false)
                }
                .pickerStyle(SegmentedPickerStyle())
                
                if !recordAsTaken {
                    TextField("Reason for skipping", text: $skippedReason)
                }
            }
            
            Section(header: Text("Notes")) {
                TextEditor(text: $notes)
                    .frame(minHeight: 100)
            }
            
            Section {
                Button(action: saveDose) {
                    Text("Save")
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .background(AppColors.primaryFallback())
                        .cornerRadius(10)
                }
                .disabled(isSaving)
            }
            
            if dose.doseId != nil {
                Section {
                    Button(action: deleteDose) {
                        Text("Delete Record")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .background(Color.red)
                            .cornerRadius(10)
                    }
                    .disabled(isSaving)
                }
            }
        }
        .navigationTitle("Record Dose")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing: Button("Cancel") {
            isPresented = false
        })
        .onAppear {
            // If there's an existing dose with a status, pre-populate the form
            if let status = dose.status {
                recordAsTaken = status == .taken
                if status == .skipped, let doseId = dose.doseId {
                    // Try to fetch existing skipped reason
                    if let existingDose = trackingStore.getDoseById(doseId) {
                        skippedReason = existingDose.skippedReason ?? ""
                        notes = existingDose.notes ?? ""
                    }
                }
            }
        }
        .overlay(
            Group {
                if isSaving {
                    ZStack {
                        Color.black.opacity(0.4)
                            .edgesIgnoringSafeArea(.all)
                        
                        VStack(spacing: 15) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Saving...")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding(25)
                        .background(Color(.systemGray3))
                        .cornerRadius(10)
                    }
                }
            }
        )
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func saveDose() {
        isSaving = true
        
        // Create dose record
        let medicationDose = MedicationDose(
            id: dose.doseId ?? UUID(),
            medicineId: dose.medicine.id,
            medicineName: dose.medicine.name,
            timestamp: Date(),
            taken: recordAsTaken,
            notes: notes.isEmpty ? nil : notes,
            skippedReason: (!recordAsTaken && !skippedReason.isEmpty) ? skippedReason : nil
        )
        
        // Save on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            if dose.doseId != nil {
                trackingStore.updateDose(medicationDose)
            } else {
                trackingStore.recordDose(medicationDose)
            }
            
            // Ensure today's doses are updated
            trackingStore.updateTodayDoses()
            
            // Update UI on main thread
            DispatchQueue.main.async {
                isSaving = false
                isPresented = false
            }
        }
    }
    
    private func deleteDose() {
        isSaving = true
        
        if let doseId = dose.doseId {
            let medicationDose = MedicationDose(
                id: doseId,
                medicineId: dose.medicine.id,
                medicineName: dose.medicine.name,
                timestamp: Date(),
                taken: false
            )
            
            // Delete on background thread
            DispatchQueue.global(qos: .userInitiated).async {
                trackingStore.deleteDose(medicationDose)
                
                // Ensure today's doses are updated
                trackingStore.updateTodayDoses()
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    isSaving = false
                    isPresented = false
                }
            }
        }
    }
}

// MARK: - AllInOneSchedulingView

struct AllInOneSchedulingView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var medicineStore: MedicineStore
    @ObservedObject var trackingStore: AdherenceTrackingStore
    
    // Step management
    @State private var step = 0 // 0 = select medicine, 1 = configure schedule
    
    // Medicine selection
    @State private var selectedMedicineId: UUID? = nil
    
    // Schedule settings
    @State private var frequency = MedicationSchedule.Frequency.daily
    @State private var selectedTimes: [Date] = []
    @State private var daysOfWeek: [Int] = [1, 2, 3, 4, 5]  // Mon-Fri by default
    @State private var customInterval = 1
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(60*60*24*30*3)  // 3 months from now
    @State private var useEndDate = false
    @State private var notes = ""
    @State private var active = true
    
    // UI state
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    // Selected medicine computed property
    private var selectedMedicine: Medicine? {
        guard let id = selectedMedicineId else { return nil }
        return medicineStore.medicines.first { $0.id == id }
    }
    
    // Medicines without schedules
    private var availableMedicines: [Medicine] {
        // Get all medicine IDs that already have schedules
        let scheduledMedicineIDs = trackingStore.getMedicinesWithSchedules()
        
        // Filter the medicines list
        return medicineStore.medicines.filter { medicine in
            !scheduledMedicineIDs.contains(medicine.id)
        }
    }
    
    var body: some View {
        Group {
            if step == 0 {
                // Step 1: Medicine selection
                medicineSelectionView
            } else {
                // Step 2: Schedule configuration
                scheduleConfigurationView
            }
        }
        .navigationTitle(step == 0 ? "Select Medicine" : "Create Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(step == 0 ? "Cancel" : "Back") {
                    if step == 0 {
                        presentationMode.wrappedValue.dismiss()
                    } else {
                        step = 0
                    }
                }
            }
            
            if step == 1 {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        createSchedule()
                    }
                    .disabled(isLoading)
                }
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    if !showErrorAlert {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            )
        }
        .onAppear {
            initializeTimes()
        }
        .overlay(
            Group {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.4)
                            .edgesIgnoringSafeArea(.all)
                        
                        VStack(spacing: 15) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Saving schedule...")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding(25)
                        .background(Color(.systemGray3))
                        .cornerRadius(10)
                    }
                }
            }
        )
    }
    
    // MARK: - Views
    
    private var medicineSelectionView: some View {
        List {
            if medicineStore.medicines.isEmpty {
                // No medicines at all
                Text("No medicines found")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else if availableMedicines.isEmpty {
                // All medicines have schedules already
                Text("All medicines already have schedules")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                // Show available medicines
                ForEach(availableMedicines) { medicine in
                    Button(action: {
                        selectedMedicineId = medicine.id
                        step = 1
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
        .listStyle(InsetGroupedListStyle())
    }
    
    private var scheduleConfigurationView: some View {
        Form {
            if let medicine = selectedMedicine {
                // Medicine info header
                Section(header: Text("Medicine")) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(medicine.name)
                                .font(.headline)
                            
                            if !medicine.manufacturer.isEmpty {
                                Text(medicine.manufacturer)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        // Medicine type indicator
                        Text(medicine.type.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(medicine.type == .prescription ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
                            .foregroundColor(medicine.type == .prescription ? .blue : .green)
                            .cornerRadius(8)
                    }
                }
                
                // Frequency section
                Section(header: Text("Frequency")) {
                    Picker("Schedule Type", selection: $frequency) {
                        ForEach(MedicationSchedule.Frequency.allCases, id: \.self) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }
                    
                    // Weekly schedule options
                    if frequency == .weekly {
                        weekdayPickerView
                    }
                    
                    // Custom interval options
                    if frequency == .custom {
                        Stepper(value: $customInterval, in: 1...30) {
                            Text("Every \(customInterval) days")
                        }
                    }
                    
                    Toggle("Active", isOn: $active)
                }
                
                // Time section
                Section(header: Text("Times")) {
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
                
                // Date range section
                Section(header: Text("Date Range")) {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    
                    Toggle("Set End Date", isOn: $useEndDate)
                    
                    if useEndDate {
                        DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
                    }
                }
                
                // Notes section
                Section(header: Text("Notes")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            } else {
                Text("Please select a medicine first")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var weekdayPickerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Days of Week")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                ForEach(0..<7) { index in
                    let day = index + 1 // 1-7 for Monday-Sunday
                    let dayNames = ["M", "T", "W", "T", "F", "S", "S"]
                    let isSelected = daysOfWeek.contains(day)
                    
                    Button(action: {
                        toggleDay(day)
                    }) {
                        Text(dayNames[index])
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 30, height: 30)
                            .background(isSelected ? AppColors.primaryFallback() : Color(.systemGray5))
                            .foregroundColor(isSelected ? .white : .primary)
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.vertical, 8)
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
    
    private func createSchedule() {
        guard let medicine = selectedMedicine else {
            showErrorAlert(message: "Please select a medicine first")
            return
        }
        
        // Validate form
        
        // Check times
        if selectedTimes.isEmpty {
            showErrorAlert(message: "Please add at least one time for the schedule")
            return
        }
        
        // Check days for weekly schedules
        if frequency == .weekly && daysOfWeek.isEmpty {
            showErrorAlert(message: "Please select at least one day of the week")
            return
        }
        
        // Check date range
        if useEndDate && endDate < startDate {
            showErrorAlert(message: "End date must be after start date")
            return
        }
        
        isLoading = true
        
        // Create schedule
        var schedule = MedicationSchedule(
            id: UUID(),
            medicineId: medicine.id,
            medicineName: medicine.name,
            frequency: frequency,
            timeOfDay: selectedTimes,
            daysOfWeek: frequency == .weekly ? daysOfWeek : nil,
            active: active,
            startDate: startDate,
            endDate: useEndDate ? endDate : nil,
            notes: notes.isEmpty ? nil : notes,
            customInterval: frequency == .custom ? customInterval : nil
        )
        
        // CRITICAL FIX:
        // Use yesterday as the start date to ensure proper display today
        schedule.startDate = Calendar.current.date(byAdding: .day, value: -1, to: startDate) ?? startDate
        
        // Call the fixed method that ensures schedules show up correctly
        DispatchQueue.global(qos: .userInitiated).async {
            trackingStore.forceSaveAndShowSchedule(schedule)
            
            DispatchQueue.main.async {
                isLoading = false
                
                // Show success message
                alertTitle = "Schedule Created"
                alertMessage = "Your medication schedule has been created successfully."
                showErrorAlert = false
                showAlert = true
            }
        }
    }
    
    private func showErrorAlert(message: String) {
        alertTitle = "Error"
        alertMessage = message
        showErrorAlert = true
        showAlert = true
    }
}

// Helper components to support the tracking view
struct ExpiryBadgeView: View {
    enum ExpiryStatus {
        case expired
        case expiringSoon
        case valid
        
        var color: Color {
            switch self {
            case .expired:
                return .red
            case .expiringSoon:
                return .yellow
            case .valid:
                return .green
            }
        }
        
        var text: String {
            switch self {
            case .expired:
                return "EXPIRED"
            case .expiringSoon:
                return "EXPIRING SOON"
            case .valid:
                return "VALID"
            }
        }
        
        var icon: String {
            switch self {
            case .expired:
                return "exclamationmark.circle.fill"
            case .expiringSoon:
                return "exclamationmark.triangle.fill"
            case .valid:
                return "checkmark.circle.fill"
            }
        }
    }
    
    let status: ExpiryStatus
    let compact: Bool
    
    init(status: ExpiryStatus, compact: Bool = false) {
        self.status = status
        self.compact = compact
    }
    
    var body: some View {
        if compact {
            compactBadge
        } else {
            fullBadge
        }
    }
    
    private var fullBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.system(size: 12))
            
            Text(status.text)
                .font(.caption)
                .fontWeight(.bold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(badgeBackground)
        .foregroundColor(badgeForeground)
        .clipShape(Capsule())
    }
    
    private var compactBadge: some View {
        Image(systemName: status.icon)
            .font(.system(size: 16))
            .foregroundColor(status.color)
    }
    
    private var badgeBackground: Color {
        switch status {
        case .expired:
            return .red
        case .expiringSoon:
            return .yellow
        case .valid:
            return .green.opacity(0.2)
        }
    }
    
    private var badgeForeground: Color {
        switch status {
        case .expired:
            return .white
        case .expiringSoon:
            return .black
        case .valid:
            return .green
        }
    }
}
