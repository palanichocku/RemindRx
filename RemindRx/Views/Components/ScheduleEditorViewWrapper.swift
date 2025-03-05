//
//  ScheduleEditorViewWrapper.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/5/25.
//

import SwiftUI

// A more robust wrapper for the ScheduleEditorView
struct ScheduleEditorViewWrapper: View {
    let schedule: MedicationSchedule
    @Binding var isPresented: Bool
    @ObservedObject var trackingStore: AdherenceTrackingStore
    
    // Added state for error handling
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            // Try-catch wrapper around editor view to prevent crashes
            ScheduleEditorView(
                schedule: ensureValidSchedule(schedule),
                isPresented: $isPresented,
                trackingStore: trackingStore
            )
            
            // Error overlay if something goes wrong during initialization
            if showError {
                VStack {
                    Spacer()
                    
                    VStack(spacing: 20) {
                        Text("Error Loading Schedule")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(errorMessage)
                            .font(.body)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Button("Close") {
                            isPresented = false
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                    .padding()
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(10)
                    .padding()
                    
                    Spacer()
                }
                .background(Color.black.opacity(0.7))
                .edgesIgnoringSafeArea(.all)
            }
        }
        .onAppear {
            // Log for debugging
            print("Opening schedule editor wrapper for: \(schedule.medicineName), frequency: \(schedule.frequency.rawValue)")
            print("Time of day count: \(schedule.timeOfDay.count)")
            if let daysOfWeek = schedule.daysOfWeek {
                print("Days of week: \(daysOfWeek)")
            }
        }
    }
    
    // Helper method to validate a schedule before showing the editor
    private func ensureValidSchedule(_ schedule: MedicationSchedule) -> MedicationSchedule {
        var validSchedule = schedule
        
        // Check for critical issues
        do {
            // Ensure valid medicine name
            if validSchedule.medicineName.isEmpty {
                validSchedule.medicineName = "Unknown Medicine"
                errorMessage = "Missing medicine name"
                showError = true
            }
            
            // Ensure timeOfDay is not empty
            if validSchedule.timeOfDay.isEmpty {
                print("Schedule has no times, adding default")
                let defaultTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
                validSchedule.timeOfDay = [defaultTime]
            }
            
            // Ensure weekly schedules have days of week
            if validSchedule.frequency == .weekly && (validSchedule.daysOfWeek == nil || validSchedule.daysOfWeek?.isEmpty == true) {
                print("Weekly schedule has no days, adding Monday")
                validSchedule.daysOfWeek = [1] // Default to Monday
            }
            
            // Ensure custom schedules have an interval
            if validSchedule.frequency == .custom && validSchedule.customInterval == nil {
                validSchedule.customInterval = 1 // Default to every day
            }
            
            // Ensure start date is not nil
            if validSchedule.startDate == nil {
                validSchedule.startDate = Date()
            }
            
            return validSchedule
        } catch {
            // If validation somehow fails, show error
            errorMessage = "Failed to validate schedule: \(error.localizedDescription)"
            showError = true
            return validSchedule
        }
    }
}
