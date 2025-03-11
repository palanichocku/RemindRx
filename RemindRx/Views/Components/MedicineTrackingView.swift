//
//  MedicineTrackingView.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/10/25.
//

import SwiftUI

struct MedicineTrackingView: View {
    @EnvironmentObject var medicineStore: MedicineStore
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Modern tab selector
            HStack(spacing: 0) {
                ForEach(["Active", "Expired"], id: \.self) { tab in
                    Button(action: {
                        withAnimation {
                            selectedTab = tab == "Active" ? 0 : 1
                        }
                    }) {
                        VStack(spacing: 10) {
                            Text(tab)
                                .font(.headline)
                                .fontWeight(selectedTab == (tab == "Active" ? 0 : 1) ? .bold : .regular)
                                .foregroundColor(selectedTab == (tab == "Active" ? 0 : 1) ? .primary : .secondary)
                            
                            Rectangle()
                                .fill(selectedTab == (tab == "Active" ? 0 : 1) ? AppColors.primaryFallback() : Color.clear)
                                .frame(height: 3)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            .background(Color(.systemBackground))
            
            Divider()
            
            // Tab content
            TabView(selection: $selectedTab) {
                // Active Medicines Tab
                ActiveMedicinesView()
                    .tag(0)
                
                // Expired Medicines Tab
                ExpiredMedicinesView()
                    .tag(1)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
        .navigationTitle("Medicine Tracking")
        .onAppear {
            medicineStore.loadMedicines()
        }
    }
}

struct ActiveMedicinesView: View {
    @EnvironmentObject var medicineStore: MedicineStore
    
    var activeMedicines: [Medicine] {
        return medicineStore.medicines.filter { !isExpired($0) }
    }
    
    var body: some View {
        if activeMedicines.isEmpty {
            emptyStateView("No Active Medicines", "Any non-expired medicines will appear here.")
        } else {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(activeMedicines) { medicine in
                        MedicineStatusCard(medicine: medicine)
                    }
                }
                .padding()
            }
        }
    }
    
    private func isExpired(_ medicine: Medicine) -> Bool {
        return medicine.expirationDate < Date()
    }
}

struct ExpiredMedicinesView: View {
    @EnvironmentObject var medicineStore: MedicineStore
    
    var expiredMedicines: [Medicine] {
        return medicineStore.medicines.filter { isExpired($0) }
    }
    
    var body: some View {
        if expiredMedicines.isEmpty {
            emptyStateView("No Expired Medicines", "Any expired medicines will appear here.")
        } else {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(expiredMedicines) { medicine in
                        MedicineStatusCard(medicine: medicine)
                    }
                }
                .padding()
            }
        }
    }
    
    private func isExpired(_ medicine: Medicine) -> Bool {
        return medicine.expirationDate < Date()
    }
}

struct MedicineStatusCard: View {
    var medicine: Medicine
    @State private var showingDetail = false
    
    var body: some View {
        Button(action: {
            showingDetail = true
        }) {
            HStack {
                // Status indicator
                statusIndicator
                    .frame(width: 44, height: 44)
                
                // Medicine info
                VStack(alignment: .leading, spacing: 4) {
                    Text(medicine.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(medicine.type == .prescription ? "Prescription" : "OTC")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 8)
                
                Spacer()
                
                // Expiration date
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Expires")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatDate(medicine.expirationDate))
                        .font(.subheadline)
                        .foregroundColor(expirationColor)
                }
                
                // Chevron
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .padding(.leading, 8)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            NavigationLink(
                destination: MedicineDetailView(medicine: medicine),
                isActive: $showingDetail,
                label: { EmptyView() }
            )
            .hidden()
        )
    }
    
    private var statusIndicator: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.2))
            
            Image(systemName: statusIconName)
                .foregroundColor(statusColor)
        }
    }
    
    private var statusColor: Color {
        if isExpired {
            return .red
        } else if isExpiringSoon {
            return .yellow
        } else {
            return .green
        }
    }
    
    private var statusIconName: String {
        if isExpired {
            return "exclamationmark.circle.fill"
        } else if isExpiringSoon {
            return "exclamationmark.triangle.fill"
        } else {
            return "checkmark.circle.fill"
        }
    }
    
    private var expirationColor: Color {
        if isExpired {
            return .red
        } else if isExpiringSoon {
            return .yellow
        } else {
            return .secondary
        }
    }
    
    private var isExpired: Bool {
        return medicine.expirationDate < Date()
    }
    
    private var isExpiringSoon: Bool {
        let timeInterval = medicine.expirationDate.timeIntervalSince(Date())
        return timeInterval > 0 && timeInterval < Double(medicine.alertInterval.days * 24 * 60 * 60)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// Helper for empty states
func emptyStateView(_ title: String, _ message: String) -> some View {
    VStack(spacing: 20) {
        Spacer()
        
        Image(systemName: "pills.circle")
            .font(.system(size: 70))
            .foregroundColor(.gray)
            .padding()
        
        Text(title)
            .font(.title2)
            .fontWeight(.semibold)
        
        Text(message)
            .multilineTextAlignment(.center)
            .foregroundColor(.secondary)
            .padding(.horizontal)
        
        Spacer()
    }
    .padding()
}
