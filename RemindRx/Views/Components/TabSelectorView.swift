//
//  TabSelectorView.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/5/25.
//
import SwiftUI

// Helper view for tab selection
struct TabSelectorView: View {
    @Binding var selectedTab: Int
    let tabs: [String]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button(action: {
                    withAnimation {
                        selectedTab = index
                    }
                }) {
                    VStack(spacing: 8) {
                        Text(tabs[index])
                            .fontWeight(selectedTab == index ? .bold : .regular)
                            .foregroundColor(selectedTab == index ? AppColors.primaryFallback() : .gray)
                        
                        // Indicator bar
                        Rectangle()
                            .fill(selectedTab == index ? AppColors.primaryFallback() : Color.clear)
                            .frame(height: 3)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .background(Color(.systemBackground))
    }
}
