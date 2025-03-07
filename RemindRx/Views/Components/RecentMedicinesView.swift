//
//  RecentMedicinesView.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/5/25.
//

import SwiftUI

struct RecentMedicinesView: View {
    @EnvironmentObject var medicineStore: MedicineStore
    
    // Add this state to track refreshes
    @State private var lastRefresh = UUID()
    
    var body: some View {
        VStack(spacing: 10) {
            ForEach(medicineStore.medicines.prefix(3)) { medicine in
                // Look up medicine by ID to ensure freshest data
                let currentMedicine = getMostCurrentMedicine(medicine)
                
                NavigationLink(destination: MedicineDetailView(medicine: medicine)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(currentMedicine.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Expires: \(formatDate(currentMedicine.expirationDate))")
                                .font(.subheadline)
                                .foregroundColor(currentMedicine.expirationDate < Date() ? .red : .secondary)
                        }
                        
                        Spacer()
                        
                        ExpiryBadgeView(status: currentMedicine.expiryStatus, compact: true)
                            .padding(.trailing, 5)
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal)
        .id(lastRefresh) // Force refresh with changing ID
        .onAppear {
            // Force refresh when view appears
            lastRefresh = UUID()
        }
    }
    
    // Helper method to get fresh medicine data
    private func getMostCurrentMedicine(_ medicine: Medicine) -> Medicine {
        if let current = medicineStore.medicines.first(where: { $0.id == medicine.id }) {
            return current
        }
        return medicine
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
