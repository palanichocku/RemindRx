import SwiftUI

struct ScheduleManagementView: View {
    @ObservedObject var trackingStore: AdherenceTrackingStore
    @EnvironmentObject var medicineStore: MedicineStore
    @State private var showingScheduleEditor = false
    @State private var selectedSchedule: MedicationSchedule?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showingDeleteConfirmation = false
    @State private var scheduleToDelete: MedicationSchedule?
    
    var body: some View {
        ZStack {
            if trackingStore.medicationSchedules.isEmpty {
                EmptyStateView(
                    icon: "calendar.badge.clock",
                    title: "No Medication Schedules",
                    message: "Tap the + button to add your first medication schedule"
                )
            } else {
                List {
                    ForEach(trackingStore.medicationSchedules) { schedule in
                        Button(action: {
                            handleScheduleSelection(schedule)
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(schedule.medicineName)
                                        .font(.headline)
                                    
                                    Text(getFrequencyText(schedule))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if !schedule.active {
                                    Text("Inactive")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.gray.opacity(0.2))
                                        .foregroundColor(.gray)
                                        .cornerRadius(4)
                                }
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contextMenu {
                            Button(role: .destructive, action: {
                                scheduleToDelete = schedule
                                showingDeleteConfirmation = true
                            }) {
                                Label("Delete Schedule", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                scheduleToDelete = schedule
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
        }
        .sheet(isPresented: $showingScheduleEditor) {
            if let schedule = selectedSchedule {
                ScheduleEditorViewWrapper(
                    schedule: schedule,
                    isPresented: $showingScheduleEditor,
                    trackingStore: trackingStore
                )
            }
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert("Delete Schedule", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                scheduleToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let schedule = scheduleToDelete {
                    handleDeleteSchedule(schedule)
                }
                scheduleToDelete = nil
            }
        } message: {
            if let schedule = scheduleToDelete {
                Text("Are you sure you want to delete the schedule for \(schedule.medicineName)? This will also delete all history records for this medicine.")
            } else {
                Text("Are you sure you want to delete this schedule? This will also delete all history records.")
            }
        }
        .onAppear {
            // Force refresh all data when view appears
            trackingStore.refreshAllData()
        }
        .onDisappear {
            // Clear selection when view disappears to prevent stale data
            selectedSchedule = nil
        }
    }
    
    // Implement explicit delete handler
    private func handleDeleteSchedule(_ schedule: MedicationSchedule) {
        print("Handling delete for schedule: \(schedule.medicineName)")
        
        // Delete the schedule and its history
        trackingStore.deleteSchedule(schedule)
        
        // Force refresh after deletion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            trackingStore.refreshAllData()
        }
    }
    
    private func handleScheduleSelection(_ schedule: MedicationSchedule) {
        do {
            // Validate the schedule before showing the editor
            let validatedSchedule = validateSchedule(schedule)
            
            // Safety check to ensure the medicine still exists
            if medicineStore.medicines.contains(where: { $0.id == schedule.medicineId }) {
                // Set the selected schedule and show the editor
                selectedSchedule = validatedSchedule
                showingScheduleEditor = true
            } else {
                // Show error because the medicine has been deleted
                errorMessage = "The medicine for this schedule no longer exists. Please delete this schedule."
                showError = true
            }
        } catch {
            // Show error alert
            errorMessage = "Could not open schedule: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func validateSchedule(_ schedule: MedicationSchedule) -> MedicationSchedule {
        var validSchedule = schedule
        
        // Ensure timeOfDay is not empty
        if validSchedule.timeOfDay.isEmpty {
            let defaultTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
            validSchedule.timeOfDay = [defaultTime]
        }
        
        // Ensure weekly schedules have days of week
        if validSchedule.frequency == .weekly && (validSchedule.daysOfWeek == nil || validSchedule.daysOfWeek?.isEmpty == true) {
            validSchedule.daysOfWeek = [1] // Default to Monday
        }
        
        // Ensure custom schedules have an interval
        if validSchedule.frequency == .custom && validSchedule.customInterval == nil {
            validSchedule.customInterval = 1 // Default to every day
        }
        
        return validSchedule
    }
    
    private func getFrequencyText(_ schedule: MedicationSchedule) -> String {
        switch schedule.frequency {
        case .daily:
            return "Daily"
        case .twiceDaily:
            return "Twice Daily"
        case .threeTimesDaily:
            return "Three Times Daily"
        case .weekly:
            if let days = schedule.daysOfWeek, !days.isEmpty {
                let dayNames = days.map { weekdayName($0) }.joined(separator: ", ")
                return "Weekly (\(dayNames))"
            } else {
                return "Weekly"
            }
        case .asNeeded:
            return "As Needed"
        case .custom:
            if let interval = schedule.customInterval {
                return "Every \(interval) days"
            } else {
                return "Custom"
            }
        }
    }
    
    private func weekdayName(_ day: Int) -> String {
        let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let index = max(0, min(day - 1, 6)) // Ensure index is in range
        return weekdays[index]
    }
}
