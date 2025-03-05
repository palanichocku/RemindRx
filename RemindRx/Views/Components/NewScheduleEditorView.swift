import SwiftUI
import Combine

struct NewScheduleEditorView: View {
    var schedule: MedicationSchedule
    @Binding var isPresented: Bool
    var trackingStore: AdherenceTrackingStore
    var onSave: (MedicationSchedule) -> Void
    var onCancel: () -> Void
    
    @State private var medicineName: String
    @State private var frequency: MedicationSchedule.Frequency
    @State private var isActive: Bool
    @State private var timeOfDay: [Date]
    @State private var daysOfWeek: [Int]
    @State private var customInterval: Int
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var notes: String
    @State private var showEndDate: Bool
    @State private var showDebugInfo = false
    
    init(schedule: MedicationSchedule, isPresented: Binding<Bool>, trackingStore: AdherenceTrackingStore, onSave: @escaping (MedicationSchedule) -> Void, onCancel: @escaping () -> Void) {
        self.schedule = schedule
        self._isPresented = isPresented
        self.trackingStore = trackingStore
        self.onSave = onSave
        self.onCancel = onCancel
        
        _medicineName = State(initialValue: schedule.medicineName)
        _frequency = State(initialValue: schedule.frequency)
        _isActive = State(initialValue: schedule.active)
        
        // Ensure timeOfDay has at least one value
        if !schedule.timeOfDay.isEmpty {
            _timeOfDay = State(initialValue: schedule.timeOfDay)
        } else {
            // Default to 9:00 AM today
            let today = Date()
            let defaultTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: today) ?? today
            _timeOfDay = State(initialValue: [defaultTime])
        }
        
        // Handle daysOfWeek for weekly schedules
        if schedule.frequency == .weekly {
            if let days = schedule.daysOfWeek, !days.isEmpty {
                _daysOfWeek = State(initialValue: days)
            } else {
                // Include today's weekday by default
                let today = Date()
                let weekday = Calendar.current.component(.weekday, from: today)
                let adjustedWeekday = weekday % 7 + 1 // Convert to Monday=1 format
                _daysOfWeek = State(initialValue: [adjustedWeekday])
            }
        } else {
            _daysOfWeek = State(initialValue: schedule.daysOfWeek ?? [])
        }
        
        // Handle customInterval for custom schedules
        if schedule.frequency == .custom {
            _customInterval = State(initialValue: schedule.customInterval ?? 1)
        } else {
            _customInterval = State(initialValue: 1)
        }
        
        // Use today as the start date by default
        _startDate = State(initialValue: schedule.startDate)
        
        // Initialize end date with a safe default (30 days from now)
        let defaultEndDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        _endDate = State(initialValue: schedule.endDate ?? defaultEndDate)
        
        _showEndDate = State(initialValue: schedule.endDate != nil)
        _notes = State(initialValue: schedule.notes ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Medicine")) {
                    Text(medicineName)
                        .foregroundColor(.primary)
                }
                
                Section(header: Text("Schedule")) {
                    Toggle("Active", isOn: $isActive)
                    
                    Picker("Frequency", selection: $frequency) {
                        ForEach(MedicationSchedule.Frequency.allCases, id: \.self) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }
                    
                    if frequency == .weekly {
                        WeekdayPickerView(selectedDays: $daysOfWeek)
                    }
                    
                    if frequency == .custom {
                        Stepper(value: $customInterval, in: 1...30) {
                            Text("Every \(customInterval) days")
                        }
                    }
                }
                
                Section(header: Text("Times")) {
                    if frequency == .daily {
                        TimePickerView(selectedTimes: $timeOfDay, count: 1)
                    } else if frequency == .twiceDaily {
                        TimePickerView(selectedTimes: $timeOfDay, count: 2)
                    } else if frequency == .threeTimesDaily {
                        TimePickerView(selectedTimes: $timeOfDay, count: 3)
                    } else {
                        TimePickerView(selectedTimes: $timeOfDay, count: 1)
                    }
                }
                
                Section(header: Text("Date Range")) {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    
                    Toggle("End Date", isOn: $showEndDate)
                    
                    if showEndDate {
                        DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                    }
                }
                
                Section(header: Text("Notes")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
                
                if showDebugInfo {
                    Section(header: Text("Debug Info")) {
                        Text("Schedule ID: \(schedule.id.uuidString)")
                            .font(.caption)
                        Text("Show End Date: \(showEndDate ? "true" : "false")")
                            .font(.caption)
                        if showEndDate {
                            Text("End Date: \(formatDate(endDate))")
                                .font(.caption)
                        }
                    }
                }
                
                Section {
                    Button(action: saveSchedule) {
                        Text("Add Schedule")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .background(AppColors.primaryFallback())
                            .cornerRadius(10)
                    }
                }
            }
            .navigationTitle("Add Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showDebugInfo.toggle() }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }
    
    private func saveSchedule() {
        print("Saving schedule...")
        
        // Create updated schedule for saving
        var updatedSchedule = schedule
        updatedSchedule.frequency = frequency
        updatedSchedule.active = isActive
        
        // Ensure there's at least one time
        if timeOfDay.isEmpty {
            let defaultTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
            updatedSchedule.timeOfDay = [defaultTime]
        } else {
            updatedSchedule.timeOfDay = timeOfDay
        }
        
        // Set days of week for weekly schedules
        if frequency == .weekly {
            if daysOfWeek.isEmpty {
                updatedSchedule.daysOfWeek = [1] // Default to Monday
            } else {
                updatedSchedule.daysOfWeek = daysOfWeek
            }
        } else {
            updatedSchedule.daysOfWeek = nil
        }
        
        // Set custom interval for custom schedules
        updatedSchedule.customInterval = frequency == .custom ? customInterval : nil
        
        updatedSchedule.startDate = startDate
        
        // Fix for end date - explicitly handle showEndDate toggle
        if showEndDate {
            updatedSchedule.endDate = endDate
        } else {
            updatedSchedule.endDate = nil
        }
        
        updatedSchedule.notes = notes.isEmpty ? nil : notes
        
        print("Schedule configured: Frequency: \(updatedSchedule.frequency.rawValue), End date: \(updatedSchedule.endDate != nil ? formatDate(updatedSchedule.endDate!) : "none")")
        
        // Call save callback with the updated schedule
        onSave(updatedSchedule)
        
        // Dismiss sheet
        isPresented = false
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}
