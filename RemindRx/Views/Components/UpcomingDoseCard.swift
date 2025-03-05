//
//  UpcomingDoseCard.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/5/25.
//
import SwiftUI

// Card for upcoming dose
struct UpcomingDoseCard: View {
    let dose: AdherenceTrackingStore.UpcomingDose
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(dose.medicine.name)
                    .font(.headline)
                
                Text(formatTime(dose.scheduledTime))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack {
                    Image(systemName: timeIcon(dose.scheduledTime))
                        .foregroundColor(timeColor(dose.scheduledTime))
                    
                    Text(timeRemaining(dose.scheduledTime))
                        .font(.subheadline)
                        .foregroundColor(timeColor(dose.scheduledTime))
                }
                
                Text(frequencyText(dose.schedule))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func timeRemaining(_ date: Date) -> String {
        let timeInterval = date.timeIntervalSince(Date())
        if timeInterval < 0 {
            return "Overdue"
        }
        
        let minutes = Int(timeInterval / 60)
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            return "\(hours) hr"
        }
    }
    
    private func timeIcon(_ date: Date) -> String {
        let timeInterval = date.timeIntervalSince(Date())
        if timeInterval < 0 {
            return "exclamationmark.circle"
        } else if timeInterval < 30 * 60 {
            return "clock.fill"
        } else {
            return "clock"
        }
    }
    
    private func timeColor(_ date: Date) -> Color {
        let timeInterval = date.timeIntervalSince(Date())
        if timeInterval < 0 {
            return .red
        } else if timeInterval < 30 * 60 {
            return .orange
        } else {
            return .blue
        }
    }
    
    private func frequencyText(_ schedule: MedicationSchedule) -> String {
        return schedule.frequency.rawValue
    }
}
