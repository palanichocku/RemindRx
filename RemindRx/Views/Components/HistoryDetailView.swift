//
//  HistoryDetailView.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/5/25.
//

import SwiftUI

// History detail view
struct HistoryDetailView: View {
    let medicine: Medicine
    let timeRange: Int
    @ObservedObject var trackingStore: AdherenceTrackingStore
    
    var body: some View {
        let doses = trackingStore.getDosesForMedicine(
            medicine.id,
            startDate: Calendar.current.date(byAdding: .day, value: -timeRange, to: Date()) ?? Date()
        )
        
        return List {
            ForEach(doses) { dose in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formatDate(dose.timestamp))
                            .font(.headline)
                        
                        if let notes = dose.notes {
                            Text(notes)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    statusView(dose.status)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    @ViewBuilder
    private func statusView(_ status: MedicationDose.DoseStatus) -> some View {
        switch status {
        case .taken:
            Label("Taken", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .missed:
            Label("Missed", systemImage: "xmark.circle.fill")
                .foregroundColor(.red)
        case .skipped:
            Label("Skipped", systemImage: "minus.circle.fill")
                .foregroundColor(.orange)
        }
    }
}
