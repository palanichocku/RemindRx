//
//  SafetyRatingCard.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/11/25.
//

import SwiftUI

struct SafetyRatingCard: View {
    @EnvironmentObject var medicineStore: MedicineStore
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Medicine Cabinet Health")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    // Refresh action if needed
                }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(alignment: .top, spacing: 20) {
                // Safety score
                VStack {
                    ZStack {
                        Circle()
                            .stroke(lineWidth: 8)
                            .opacity(0.3)
                            .foregroundColor(safetyScoreColor)
                        
                        Circle()
                            .trim(from: 0.0, to: CGFloat(safetyScore) / 100)
                            .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                            .foregroundColor(safetyScoreColor)
                            .rotationEffect(Angle(degrees: 270.0))
                        
                        Text("\(Int(safetyScore))")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundColor(safetyScoreColor)
                    }
                    .frame(width: 100, height: 100)
                    
                    Text("Safety Score")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                
                // Safety metrics
                VStack(alignment: .leading, spacing: 12) {
                    safetyMetricRow(
                        label: "Expired",
                        value: "\(medicineStore.expiredMedicines.count) medicines",
                        icon: "exclamationmark.circle",
                        color: .red
                    )
                    
                    safetyMetricRow(
                        label: "Expiring Soon",
                        value: "\(medicineStore.expiringSoonMedicines.count) medicines",
                        icon: "clock",
                        color: .orange
                    )
                    
                    safetyMetricRow(
                        label: "Valid",
                        value: "\(validMedicinesCount) medicines",
                        icon: "checkmark.circle",
                        color: .green
                    )
                }
            }
            
            // Recommendations
            if let recommendation = safetyRecommendation {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    
                    Text(recommendation)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // Helper methods
    private var safetyScore: Double {
        if medicineStore.medicines.isEmpty {
            return 0
        }
        
        let expiredPercentage = Double(medicineStore.expiredMedicines.count) / Double(medicineStore.medicines.count)
        let expiringSoonPercentage = Double(medicineStore.expiringSoonMedicines.count) / Double(medicineStore.medicines.count)
        
        // Calculate score - lower percentages of expired/expiring means higher score
        let score = 100 - (expiredPercentage * 100) - (expiringSoonPercentage * 30)
        return max(0, min(100, score))
    }
    
    private var safetyScoreColor: Color {
        if safetyScore >= 80 {
            return .green
        } else if safetyScore >= 50 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var validMedicinesCount: Int {
        return medicineStore.medicines.count - medicineStore.expiredMedicines.count - medicineStore.expiringSoonMedicines.count
    }
    
    private var safetyRecommendation: String? {
        if medicineStore.medicines.isEmpty {
            return "Add medicines to see cabinet health insights"
        }
        
        if medicineStore.expiredMedicines.count > 0 {
            return "Consider removing \(medicineStore.expiredMedicines.count) expired medicines from your cabinet"
        } else if medicineStore.expiringSoonMedicines.count > 0 {
            return "Plan to replace \(medicineStore.expiringSoonMedicines.count) medicines expiring soon"
        } else if medicineStore.medicines.count < 5 {
            return "Your cabinet is well-maintained! Consider adding essential medicines for emergencies"
        }
        
        return "Your medicine cabinet is in excellent shape!"
    }
    
    private func safetyMetricRow(label: String, value: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading) {
                Text(label)
                    .font(.subheadline)
                
                Text(value)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

