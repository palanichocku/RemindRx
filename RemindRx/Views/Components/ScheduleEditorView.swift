import SwiftUI

// A more robust implementation of the Schedule Editor
struct ScheduleEditorView: View {
    // Core properties - schedule and binding
    let schedule: MedicationSchedule
    @Binding var isPresented: Bool
    @ObservedObject var trackingStore: AdherenceTrackingStore
    
    // State properties with safe initialization
    @State private var medicineName: String
    @State private var frequency: MedicationSchedule.Frequency
    @State private var isActive: Bool
    @State private var timeOfDay: [Date]
    @State private var daysOfWeek: [Int]
    @State private var customInterval: Int
    @State private var startDate: Date
    @State private var endDate: Date?
    @State private var notes: String
    @State private var showEndDate: Bool
    
    // Debugging/error handling
    @State private var showDebugInfo = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    // Safer initializer with defensive coding
    init(schedule: MedicationSchedule, isPresented: Binding<Bool>, trackingStore: AdherenceTrackingStore) {
        print("Initializing ScheduleEditorView for \(schedule.medicineName)")
        
        self.schedule = schedule
        self._isPresented = isPresented
        self.trackingStore = trackingStore
        
        // Initialize state properties with safe defaults
        _medicineName = State(initialValue: schedule.medicineName)
        _frequency = State(initialValue: schedule.frequency)
        _isActive = State(initialValue: schedule.active)
        
        // Handle timeOfDay safely
        if let firstTime = schedule.timeOfDay.first {
            _timeOfDay = State(initialValue: schedule.timeOfDay)
        } else {
            // Default to 9:00 AM
            let defaultTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
            _timeOfDay = State(initialValue: [defaultTime])
        }
        
        // Handle daysOfWeek safely for weekly schedules
        if schedule.frequency == .weekly {
            if let days = schedule.daysOfWeek, !days.isEmpty {
                _daysOfWeek = State(initialValue: days)
            } else {
                _daysOfWeek = State(initialValue: [1]) // Default to Monday
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
        
        // Other properties
        _startDate = State(initialValue: schedule.startDate)
        _endDate = State(initialValue: schedule.endDate)
        _showEndDate = State(initialValue: schedule.endDate != nil)
        _notes = State(initialValue: schedule.notes ?? "")
    }
    
    var body: some View {
        NavigationView {
            ZStack {
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
                            DatePicker("End Date", selection: Binding(
                                get: { self.endDate ?? Date().addingTimeInterval(60*60*24*30) },
                                set: { self.endDate = $0 }
                            ), displayedComponents: .date)
                        }
                    }
                    
                    Section(header: Text("Notes")) {
                        TextEditor(text: $notes)
                            .frame(minHeight: 80)
                    }
                    
                    // Debug information (hidden unless needed)
                    if showDebugInfo {
                        Section(header: Text("Debug Info")) {
                            Text("Schedule ID: \(schedule.id.uuidString)")
                            Text("Medicine ID: \(schedule.medicineId.uuidString)")
                            Text("Days of Week: \(daysOfWeek.map { String($0) }.joined(separator: ", "))")
                            Text("Times Count: \(timeOfDay.count)")
                        }
                    }
                    
                    Section {
                        Button(action: saveSchedule) {
                            Text("Save Schedule")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                                .padding(.vertical, 10)
                                .background(AppColors.primaryFallback())
                                .cornerRadius(10)
                        }
                    }
                    
                    // Add a cancel button at the bottom too
                    Section {
                        Button(action: { isPresented = false }) {
                            Text("Cancel")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.red)
                                .padding(.vertical, 10)
                        }
                    }
                }
                
                // Error overlay if something goes wrong
                if showError {
                    VStack {
                        Spacer()
                        
                        Text(errorMessage)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(10)
                            .padding()
                        
                        Button("Dismiss") {
                            showError = false
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(8)
                        
                        Spacer().frame(height: 100)
                    }
                }
            }
            .navigationTitle("Edit Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                // Add debug toggle in development
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showDebugInfo.toggle() }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.gray)
                    }
                }
            }
            .onAppear {
                print("ScheduleEditorView appeared for \(medicineName)")
                
                // Ensure timeOfDay has at least one value
                if timeOfDay.isEmpty {
                    let defaultTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
                    timeOfDay = [defaultTime]
                }
                
                // Ensure weekly schedules have at least one day selected
                if frequency == .weekly && daysOfWeek.isEmpty {
                    daysOfWeek = [1] // Default to Monday
                }
            }
        }
    }
    
    private func saveSchedule() {
        do {
            // Create updated schedule with validation
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
            updatedSchedule.endDate = showEndDate ? endDate : nil
            updatedSchedule.notes = notes.isEmpty ? nil : notes
            
            // Debug log
            print("Saving schedule: \(updatedSchedule.medicineName), frequency: \(updatedSchedule.frequency.rawValue)")
            
            // Update in store
            trackingStore.updateSchedule(updatedSchedule)
            
            isPresented = false
        } catch {
            print("Error saving schedule: \(error)")
            errorMessage = "Failed to save schedule: \(error.localizedDescription)"
            showError = true
        }
    }
}
