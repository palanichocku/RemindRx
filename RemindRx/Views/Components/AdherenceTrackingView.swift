import SwiftUI

struct AdherenceTrackingView: View {
    @EnvironmentObject var medicineStore: MedicineStore
    @EnvironmentObject var adherenceStore: AdherenceTrackingStore
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            HStack(spacing: 0) {
                ForEach(["Schedules", "History"], id: \.self) { tab in
                    Button(action: {
                        withAnimation {
                            selectedTab = tab == "Schedules" ? 0 : 1
                        }
                    }) {
                        VStack(spacing: 10) {
                            Text(tab)
                                .font(.headline)
                                .foregroundColor(selectedTab == (tab == "Schedules" ? 0 : 1) ? .primary : .secondary)
                            
                            Rectangle()
                                .fill(selectedTab == (tab == "Schedules" ? 0 : 1) ? AppColors.primaryFallback() : Color.clear)
                                .frame(height: 3)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            .background(Color(.systemBackground))
            
            Divider()
            
            // Tab content
            TabView(selection: $selectedTab) {
                // Schedules Tab
                SchedulesTabView()
                    .tag(0)
                
                // History Tab
                HistoryTabView()
                    .tag(1)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
        .navigationTitle("Medication Tracking")
        .onAppear {
            // Ensure data is fresh
            adherenceStore.refreshAllData()
            adherenceStore.loadHistoryRecords()
        }
    }
}

struct SchedulesTabView: View {
    @EnvironmentObject var medicineStore: MedicineStore
    @EnvironmentObject var adherenceStore: AdherenceTrackingStore
    @State private var showingAddScheduleForm = false
    @State private var selectedMedicine: Medicine? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if adherenceStore.medicationSchedules.isEmpty {
                    emptySchedulesView
                } else {
                    ForEach(adherenceStore.medicationSchedules) { schedule in
                        ScheduleCard(schedule: schedule)
                    }
                }
            }
            .padding()
        }
        .refreshable {
            adherenceStore.loadSchedules()
        }
        .sheet(isPresented: $showingAddScheduleForm) {
            if let medicine = selectedMedicine {
                NavigationView {
                    ScheduleFormView(
                        isPresented: $showingAddScheduleForm,
                        medicine: medicine
                    )
                }
            }
        }
    }
    
    private var emptySchedulesView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 70))
                .foregroundColor(.gray)
                .padding()
            
            Text("No Medication Schedules")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("You haven't created any medication schedules yet. Add a schedule to start tracking your medications.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            if !medicineStore.medicines.isEmpty {
                Menu {
                    ForEach(medicineStore.medicines) { medicine in
                        Button(action: {
                            selectedMedicine = medicine
                            showingAddScheduleForm = true
                        }) {
                            Text(medicine.name)
                        }
                    }
                } label: {
                    Text("Add Schedule")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(AppColors.primaryFallback())
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.top)
            } else {
                Text("Add medicines first to create schedules")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .padding(.top)
            }
            
            Spacer()
        }
    }
}

struct ScheduleCard: View {
    var schedule: MedicationSchedule
    @EnvironmentObject var adherenceStore: AdherenceTrackingStore
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(schedule.medicineName)
                    .font(.headline)
                
                Spacer()
                
                // Active/inactive indicator
                Text(schedule.active ? "Active" : "Inactive")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(schedule.active ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                    .foregroundColor(schedule.active ? .green : .gray)
                    .cornerRadius(10)
            }
            
            Divider()
            
            // Schedule details
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        Text(frequencyText)
                    } icon: {
                        Image(systemName: "clock")
                            .foregroundColor(.blue)
                    }
                    
                    if !schedule.timeOfDay.isEmpty {
                        Label {
                            Text(timesText)
                        } icon: {
                            Image(systemName: "alarm")
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Label {
                        Text(dateRangeText)
                    } icon: {
                        Image(systemName: "calendar")
                            .foregroundColor(.purple)
                    }
                }
                
                Spacer()
            }
            
            // Actions
            HStack {
                Spacer()
                
                Button(action: {
                    showingEditSheet = true
                }) {
                    Label("Edit", systemImage: "pencil")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
                
                Button(action: {
                    showingDeleteAlert = true
                }) {
                    Label("Delete", systemImage: "trash")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .sheet(isPresented: $showingEditSheet) {
            NavigationView {
                ScheduleFormView(
                    isPresented: $showingEditSheet,
                    schedule: schedule
                )
            }
        }
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("Delete Schedule"),
                message: Text("Are you sure you want to delete this medication schedule? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    adherenceStore.deleteSchedule(schedule)
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    private var frequencyText: String {
        switch schedule.frequency {
        case .daily:
            return "Daily"
        case .twiceDaily:
            return "Twice Daily"
        case .threeTimesDaily:
            return "Three Times Daily"
        case .weekly:
            if let days = schedule.daysOfWeek, !days.isEmpty {
                let dayNames = days.map { getDayName($0) }.joined(separator: ", ")
                return "Weekly on \(dayNames)"
            } else {
                return "Weekly"
            }
        case .custom:
            if let interval = schedule.customInterval {
                return "Every \(interval) day\(interval > 1 ? "s" : "")"
            } else {
                return "Custom"
            }
        case .asNeeded:
            return "As Needed"
        }
    }
    
    private var timesText: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        return schedule.timeOfDay
            .map { formatter.string(from: $0) }
            .joined(separator: ", ")
    }
    
    private var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        let startDate = formatter.string(from: schedule.startDate)
        if let endDate = schedule.endDate {
            return "\(startDate) to \(formatter.string(from: endDate))"
        } else {
            return "From \(startDate)"
        }
    }
    
    private func getDayName(_ day: Int) -> String {
        let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        if day >= 1 && day <= 7 {
            return days[day-1]
        }
        return ""
    }
}

struct HistoryTabView: View {
    @EnvironmentObject var adherenceStore: AdherenceTrackingStore
    @State private var selectedPeriod: Int = 1  // 0: Today, 1: Week, 2: Month, 3: All
    
    var body: some View {
        VStack(spacing: 0) {
            // Period selector
            Picker("Time Period", selection: $selectedPeriod) {
                Text("Today").tag(0)
                Text("Week").tag(1)
                Text("Month").tag(2)
                Text("All").tag(3)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            if filteredHistory.isEmpty {
                emptyHistoryView
            } else {
                List {
                    ForEach(filteredHistory) { record in
                        HistoryRecordRow(record: record)
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .onAppear {
            adherenceStore.loadHistoryRecords()
        }
        .refreshable {
            adherenceStore.loadHistoryRecords()
        }
    }
    
    private var filteredHistory: [MedicationHistoryRecord] {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedPeriod {
        case 0: // Today
            let startOfDay = calendar.startOfDay(for: now)
            return adherenceStore.getHistoryInRange(start: startOfDay)
            
        case 1: // Week
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return adherenceStore.getHistoryInRange(start: weekAgo)
            
        case 2: // Month
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return adherenceStore.getHistoryInRange(start: monthAgo)
            
        case 3: // All
            return adherenceStore.historyRecords.sorted { $0.recordedTime > $1.recordedTime }
            
        default:
            return []
        }
    }
    
    private var emptyHistoryView: some View {
        VStack(spacing: 25) {
            Spacer()
            
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 70))
                .foregroundColor(.gray)
                .padding()
            
            Text("No Medication History")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("No medication records found for this time period. Take your medications using the Dosage Tracking feature to see your history here.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Spacer()
        }
    }
}

struct HistoryRecordRow: View {
    var record: MedicationHistoryRecord
    
    var body: some View {
        HStack(spacing: 15) {
            // Status indicator
            statusIcon
            
            // Medicine info
            VStack(alignment: .leading, spacing: 4) {
                Text(record.medicineName)
                    .font(.headline)
                
                Text("Scheduled: \(formatDate(record.scheduledTime))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Recorded: \(formatDate(record.recordedTime))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Time difference
            timeDifferenceText
        }
        .padding(.vertical, 8)
    }
    
    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.2))
                .frame(width: 40, height: 40)
            
            Image(systemName: statusImageName)
                .foregroundColor(statusColor)
        }
    }
    
    private var statusColor: Color {
        switch record.status {
        case .taken: return .green
        case .skipped: return .orange
        case .missed: return .red
        }
    }
    
    private var statusImageName: String {
        switch record.status {
        case .taken: return "checkmark.circle.fill"
        case .skipped: return "xmark.circle.fill"
        case .missed: return "exclamationmark.circle.fill"
        }
    }
    
    private var timeDifferenceText: some View {
        let timeDifference = record.recordedTime.timeIntervalSince(record.scheduledTime)
        let isLate = timeDifference > 0
        let absTimeDifference = abs(timeDifference)
        
        let hours = Int(absTimeDifference) / 3600
        let minutes = (Int(absTimeDifference) % 3600) / 60
        
        let timeText: String
        if hours > 0 {
            timeText = "\(hours)h \(minutes)m"
        } else {
            timeText = "\(minutes)m"
        }
        
        return Text(isLate ? "\(timeText) late" : "\(timeText) early")
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isLate ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
            .foregroundColor(isLate ? .orange : .green)
            .cornerRadius(8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
