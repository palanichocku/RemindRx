import SwiftUI
import Combine

// Fixed SimpleScheduleCreationView with no build errors
struct SimpleScheduleCreationView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var trackingStore: AdherenceTrackingStore
    
    let medicine: Medicine // Medicine to create schedule for
    var onComplete: () -> Void
    
    // State for schedule properties
    @State private var frequency = MedicationSchedule.Frequency.daily
    @State private var morningTime = Date() // 9:00 AM by default
    @State private var eveningTime = Date() // 6:00 PM by default
    @State private var daysOfWeek = [1, 2, 3, 4, 5] // Mon-Fri by default
    @State private var customInterval = 1
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(60*60*24*30) // 30 days from now
    @State private var useEndDate = false
    @State private var notes = ""
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    init(trackingStore: AdherenceTrackingStore, medicine: Medicine, onComplete: @escaping () -> Void) {
        self.trackingStore = trackingStore
        self.medicine = medicine
        self.onComplete = onComplete
        
        // Initialize times with better defaults
        let calendar = Calendar.current
        let today = Date()
        let morning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: today) ?? today
        let evening = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: today) ?? today
        
        // Use _State for initialization
        _morningTime = State(initialValue: morning)
        _eveningTime = State(initialValue: evening)
    }
    
    var body: some View {
        // Use VStack instead of NavigationView to avoid toolbar issues
        VStack(spacing: 0) {
            // Custom navigation bar
            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .padding(.leading)
                
                Spacer()
                
                Text("Add Schedule")
                    .font(.headline)
                
                Spacer()
                
                // Empty view for balance
                Button("") {}.opacity(0)
                    .padding(.trailing)
            }
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .shadow(color: Color.black.opacity(0.1), radius: 1)
            
            // Content
            ZStack {
                ScrollView {
                    VStack(spacing: 20) {
                        // Medicine info card
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Medicine")
                                .font(.headline)
                                .padding(.bottom, 5)
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(medicine.name)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    
                                    Text(medicine.manufacturer)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        
                        // Schedule type
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Schedule Type")
                                .font(.headline)
                                .padding(.bottom, 5)
                            
                            Picker("Frequency", selection: $frequency) {
                                Text("Daily").tag(MedicationSchedule.Frequency.daily)
                                Text("Twice Daily").tag(MedicationSchedule.Frequency.twiceDaily)
                                Text("Weekly").tag(MedicationSchedule.Frequency.weekly)
                                Text("As Needed").tag(MedicationSchedule.Frequency.asNeeded)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                        .padding(.horizontal)
                        
                        // Times
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Times")
                                .font(.headline)
                                .padding(.bottom, 5)
                            
                            VStack(spacing: 15) {
                                if frequency == .daily {
                                    // Daily - morning time only
                                    HStack {
                                        Text("Time")
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        DatePicker("", selection: $morningTime, displayedComponents: .hourAndMinute)
                                            .labelsHidden()
                                    }
                                } else if frequency == .twiceDaily {
                                    // Twice daily - morning and evening
                                    HStack {
                                        Text("Morning")
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        DatePicker("", selection: $morningTime, displayedComponents: .hourAndMinute)
                                            .labelsHidden()
                                    }
                                    
                                    HStack {
                                        Text("Evening")
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        DatePicker("", selection: $eveningTime, displayedComponents: .hourAndMinute)
                                            .labelsHidden()
                                    }
                                } else if frequency == .weekly {
                                    // Weekly - time + days
                                    HStack {
                                        Text("Time")
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        DatePicker("", selection: $morningTime, displayedComponents: .hourAndMinute)
                                            .labelsHidden()
                                    }
                                    
                                    // Day selection
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("Days of Week")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        
                                        HStack {
                                            weekdayToggle("M", day: 1)
                                            weekdayToggle("T", day: 2)
                                            weekdayToggle("W", day: 3)
                                            weekdayToggle("T", day: 4)
                                            weekdayToggle("F", day: 5)
                                            weekdayToggle("S", day: 6)
                                            weekdayToggle("S", day: 7)
                                        }
                                    }
                                    .padding(.vertical, 5)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        
                        // Date range
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Date Range")
                                .font(.headline)
                                .padding(.bottom, 5)
                            
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
                        .padding(.horizontal)
                        
                        // Notes
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Notes")
                                .font(.headline)
                                .padding(.bottom, 5)
                            
                            TextField("Optional notes", text: $notes)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        
                        // Save button
                        Button(action: createSchedule) {
                            Text("Save Schedule")
                                .frame(maxWidth: .infinity)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .background(AppColors.primaryFallback())
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        .padding(.bottom, 30)
                    }
                    .padding(.top, 20)
                }
                
                // Loading overlay
                if isLoading {
                    Color.black.opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                    
                    ProgressView("Creating schedule...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 3)
                }
                
                // Error message
                if let error = errorMessage {
                    VStack {
                        Spacer()
                        Text(error)
                            .padding()
                            .background(Color.red.opacity(0.9))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding()
                        Spacer().frame(height: 40)
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .edgesIgnoringSafeArea(.bottom)
    }
    
    // Helper to create a weekday toggle button
    private func weekdayToggle(_ label: String, day: Int) -> some View {
        let isSelected = daysOfWeek.contains(day)
        
        return Button(action: {
            if isSelected {
                // Only remove if we have more than one day selected
                if daysOfWeek.count > 1 {
                    daysOfWeek.removeAll { $0 == day }
                }
            } else {
                daysOfWeek.append(day)
            }
        }) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 30, height: 30)
                .background(isSelected ? AppColors.primaryFallback() : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Circle())
        }
    }
    
    // Get timeOfDay array for the schedule based on current settings
    private func getTimeOfDayArray() -> [Date] {
        switch frequency {
        case .daily, .weekly, .asNeeded, .custom:
            return [morningTime]
            
        case .twiceDaily:
            return [morningTime, eveningTime]
            
        case .threeTimesDaily:
            // We only have UI for two times, add a midday time
            let calendar = Calendar.current
            let noon = calendar.date(
                bySettingHour: 12,
                minute: 0,
                second: 0,
                of: Date()
            ) ?? Date()
            
            return [morningTime, noon, eveningTime]
        }
    }
    
    // Create and save the schedule
    private func createSchedule() {
        isLoading = true
        errorMessage = nil
        
        do {
            // Create a new schedule
            var schedule = MedicationSchedule(
                id: UUID(),
                medicineId: medicine.id,
                medicineName: medicine.name,
                frequency: frequency,
                timeOfDay: getTimeOfDayArray(),
                daysOfWeek: frequency == .weekly ? daysOfWeek : nil,
                active: true,
                startDate: startDate,
                endDate: useEndDate ? endDate : nil,
                notes: notes.isEmpty ? nil : notes
            )
            
            // Set custom interval if needed
            if frequency == .custom {
                schedule.customInterval = customInterval
            }
            
            // Save the schedule
            trackingStore.addScheduleAndUpdateViews(schedule)
            
            // Show success message
            print("Schedule created successfully")
            
            // Wait a moment before dismissing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isLoading = false
                onComplete()
                presentationMode.wrappedValue.dismiss()
            }
        } catch {
            // Show error
            isLoading = false
            errorMessage = "Failed to create schedule: \(error.localizedDescription)"
            
            // Auto-hide after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                errorMessage = nil
            }
        }
    }
}
