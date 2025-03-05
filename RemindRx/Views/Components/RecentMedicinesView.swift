//
//  RecentMedicinesView.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/5/25.
//

import SwiftUI

struct RecentMedicinesView: View {
    let medicines: [Medicine]
    
    var body: some View {
        VStack(spacing: 10) {
            ForEach(medicines) { medicine in
                NavigationLink(destination: MedicineDetailView(medicine: medicine)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(medicine.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Expires: \(formatDate(medicine.expirationDate))")
                                .font(.subheadline)
                                .foregroundColor(medicine.expirationDate < Date() ? .red : .secondary)
                        }
                        
                        Spacer()
                        
                        ExpiryBadgeView(status: medicine.expiryStatus, compact: true)
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
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

