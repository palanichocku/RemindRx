//
//  ShoppingListView.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/11/25.
//
import SwiftUI

struct ShoppingListView: View {
    @EnvironmentObject var medicineStore: MedicineStore
    @State private var showOnlyExpired = false
    
    var body: some View {
        ZStack {
            if shoppingItems.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "cart")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text(medicineStore.medicines.isEmpty
                        ? "Add medicines to generate a shopping list"
                        : "No medicines need replacement")
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack {
                    // Filter toggle
                    Toggle("Show only expired", isOn: $showOnlyExpired)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    
                    List {
                        ForEach(shoppingItems) { item in
                            ShoppingItemRow(item: item)
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
        }
    }
    
    private var shoppingItems: [Medicine] {
        if showOnlyExpired {
            return medicineStore.expiredMedicines
        } else {
            return medicineStore.expiredMedicines + medicineStore.expiringSoonMedicines
        }
    }
}

struct ShoppingItemRow: View {
    let item: Medicine
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                
                Text(item.manufacturer)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: isExpired ? "exclamationmark.circle.fill" : "clock")
                        .foregroundColor(isExpired ? .red : .orange)
                        .font(.caption)
                    
                    Text(isExpired ? "Expired on \(formatDate(item.expirationDate))" : "Expires on \(formatDate(item.expirationDate))")
                        .font(.caption)
                        .foregroundColor(isExpired ? .red : .orange)
                }
            }
            
            Spacer()
            
            // Type badge
            Text(item.type.rawValue)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(item.type == .prescription ? Color.blue : Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
        }
        .padding(.vertical, 4)
    }
    
    private var isExpired: Bool {
        return item.expirationDate < Date()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
