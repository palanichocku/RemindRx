import SwiftUI

struct DosageTrackingView: View {
    @EnvironmentObject var medicineStore: MedicineStore
    @EnvironmentObject var adherenceStore: AdherenceTrackingStore
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedTab: Int = 0
    private let tabs = ["Today", "Upcoming"]
    @State private var isFirstAppear = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with tabs
            VStack(spacing: 15) {
                // Close button
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Text("Dosage Tracking")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Empty space to balance the close button
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.clear)
                }
                .padding(.horizontal)
                
                // Modern pill-shaped tabs
                HStack(spacing: 8) {
                    ForEach(0..<tabs.count, id: \.self) { index in
                        TabButton(
                            title: tabs[index],
                            isSelected: selectedTab == index,
                            action: {
                                withAnimation {
                                    selectedTab = index
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top)
            .background(Color(.systemBackground))
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            
            // Tab content
            TabView(selection: $selectedTab) {
                // TODAY TAB
                todayDosesTab
                    .tag(0)
                
                // UPCOMING TAB
                upcomingDosesTab
                    .tag(1)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
        .onAppear {
            print("DosageTrackingView appeared - Running diagnostics")
            // Fix schedule times first
            adherenceStore.checkAndFixScheduleTimes()
            // Force data to appear in today view
            adherenceStore.forceSchedulesToShowToday()
            adherenceStore.updateUpcomingDoses()
            // Run diagnostics to help troubleshoot
            adherenceStore.diagnosticScheduleCheck()
            // Force data to appear
            adherenceStore.forceSchedulesToShowToday()
            
            // If this is the first time the view appears, do a special initialization
           if isFirstAppear {
               isFirstAppear = false
               
               // Make sure schedules show up - extra insurance
               DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                   adherenceStore.ensureAllSchedulesHaveValidTimes()
                   adherenceStore.forceSchedulesToShowToday()
                   
                   // Force UI update
                   adherenceStore.objectWillChange.send()
               }
           }
            // Update the UI
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                adherenceStore.objectWillChange.send()
            }
        }
    }
    
    // TODAY TAB
    private var todayDosesTab: some View {
        ScrollView {
            if adherenceStore.todayDoses.isEmpty {
                emptyTodayView
            } else {
                VStack(spacing: 20) {
                    ForEach(adherenceStore.todayDoses.sorted(by: { $0.scheduledTime < $1.scheduledTime })) { dose in
                        DoseCardView(dose: dose, adherenceStore: adherenceStore)
                    }
                }
                .padding()
            }
        }
        .refreshable {
            // Fix schedule times first
            adherenceStore.checkAndFixScheduleTimes()
            // Force a complete data refresh using the special method
            adherenceStore.forceSchedulesToShowToday()
            adherenceStore.refreshAllData()
        }
        .onAppear {
            // Force schedule data to show in today view
            adherenceStore.forceSchedulesToShowToday()
        }
    }
    
    // UPCOMING TAB
    private var upcomingDosesTab: some View {
        ScrollView {
            if adherenceStore.upcomingDoses.isEmpty {
                emptyUpcomingView
            } else {
                VStack(spacing: 20) {
                    ForEach(adherenceStore.upcomingDoses) { dose in
                        UpcomingDoseCardView(dose: dose)
                    }
                }
                .padding()
            }
        }
        .refreshable {
            adherenceStore.refreshAllData()
            adherenceStore.updateUpcomingDoses(forceShow: true)
        }
        .onAppear {
            // Make sure upcoming doses are updated
            adherenceStore.updateUpcomingDoses(forceShow: true)
        }
    }
    
    private var emptyTodayView: some View {
        VStack(spacing: 25) {
            Spacer()
            
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No doses scheduled for today")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("Your scheduled medications will appear here")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
    
    private var emptyUpcomingView: some View {
        VStack(spacing: 25) {
            Spacer()
            
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No upcoming doses scheduled")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("Future scheduled medications will appear here")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
}

// Modern pill-shaped tab button
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .medium)
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .background(
                    Capsule()
                        .fill(isSelected ? AppColors.primaryFallback() : Color(.systemGray5))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .frame(maxWidth: .infinity)
    }
}

// Modern Dose Card with inline action buttons
struct DoseCardView: View {
    let dose: AdherenceTrackingStore.TodayDose
    let adherenceStore: AdherenceTrackingStore
    @State private var isLoading: Bool = false
    
    private var isPastDue: Bool {
        return Date() > dose.scheduledTime
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Medicine info
            HStack {
                Image(systemName: dose.medicine.type == .prescription ? "pills.fill" : "cross.case.fill")
                    .font(.title3)
                    .foregroundColor(dose.medicine.type == .prescription ? .blue : .green)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(dose.medicine.name)
                        .font(.headline)
                    
                    Text(dose.medicine.description.isEmpty ? "No description" : dose.medicine.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text(formatTime(dose.scheduledTime))
                    .font(.subheadline)
                    .foregroundColor(isPastDue ? .red : .secondary)
            }
            
            // Status display
            if let status = dose.status {
                statusView(for: status)
            } else {
                // Action buttons
                HStack(spacing: 12) {
                    Spacer()
                    
                    actionButton(
                        title: "Skip",
                        icon: "xmark.circle.fill",
                        color: .orange,
                        action: {
                            markDose(.skipped)
                        }
                    )
                    
                    actionButton(
                        title: "Taken",
                        icon: "checkmark.circle.fill",
                        color: .green,
                        action: {
                            markDose(.taken)
                        }
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(borderColor, lineWidth: 1)
        )
        .overlay(
            Group {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(15)
                }
            }
        )
    }
    
    private var borderColor: Color {
        if let status = dose.status {
            switch status {
            case .taken: return .green.opacity(0.3)
            case .missed: return .red.opacity(0.3)
            case .skipped: return .orange.opacity(0.3)
            }
        } else if isPastDue {
            return .red.opacity(0.3)
        }
        return Color.clear
    }
    
    private func statusView(for status: MedicationDose.DoseStatus) -> some View {
        HStack {
            Spacer()
            
            Group {
                switch status {
                case .taken:
                    Label("Taken", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                case .missed:
                    Label("Missed", systemImage: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                case .skipped:
                    Label("Skipped", systemImage: "xmark.circle.fill")
                        .foregroundColor(.orange)
                }
            }
            .font(.subheadline)
            .padding(.vertical, 8)
            .padding(.horizontal, 20)
            .background(
                Capsule()
                    .fill(statusBackgroundColor(for: status))
            )
        }
    }
    
    private func statusBackgroundColor(for status: MedicationDose.DoseStatus) -> Color {
        switch status {
        case .taken: return Color.green.opacity(0.1)
        case .missed: return Color.red.opacity(0.1)
        case .skipped: return Color.orange.opacity(0.1)
        }
    }
    
    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.subheadline)
                Text(title)
                    .font(.subheadline)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 15)
            .background(
                Capsule()
                    .fill(color.opacity(0.1))
            )
            .foregroundColor(color)
        }
    }
    
    // Update the markDose method in DoseCardView
    private func markDose(_ doseStatus: MedicationDose.DoseStatus) {
        isLoading = true
        
        // Simulate a short delay for the loading indicator
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: DispatchWorkItem(block: {
            // Create a new dose record based on the structure required in your app
            let newDose = MedicationDose(
                id: dose.doseId ?? UUID(),  // Use existing ID if available, otherwise create new
                medicineId: dose.medicine.id,
                medicineName: dose.medicine.name,
                timestamp: Date(),
                taken: doseStatus == .taken  // Convert DoseStatus to boolean for 'taken'
            )
            
            // If we already have a dose record, update it
            if dose.doseId != nil {
                adherenceStore.updateDose(newDose)
            } else {
                adherenceStore.recordDose(newDose)
            }
            
            // Add to history
            adherenceStore.addToHistory(
                medicineId: dose.medicine.id,
                medicineName: dose.medicine.name,
                scheduledTime: dose.scheduledTime,
                recordedTime: Date(),
                status: doseStatus
            )
            
            // Refresh the data
            adherenceStore.refreshAllData()
            isLoading = false
        }))
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Card for upcoming doses
struct UpcomingDoseCardView: View {
    let dose: AdherenceTrackingStore.UpcomingDose
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: dose.medicine.type == .prescription ? "pills.fill" : "cross.case.fill")
                    .font(.title3)
                    .foregroundColor(dose.medicine.type == .prescription ? .blue : .green)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(dose.medicine.name)
                        .font(.headline)
                    
                    Text(dose.medicine.description.isEmpty ? "No description" : dose.medicine.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text(formatDateTime(dose.scheduledTime))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        // If it's today, just show time
        if Calendar.current.isDateInToday(date) {
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            return formatter.string(from: date)
        }
        
        // If it's tomorrow, show "Tomorrow at time"
        if Calendar.current.isDateInTomorrow(date) {
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            return "Tomorrow at " + formatter.string(from: date)
        }
        
        // Otherwise show the day and time
        formatter.dateFormat = "EEE, MMM d • h:mm a"
        return formatter.string(from: date)
    }
}
