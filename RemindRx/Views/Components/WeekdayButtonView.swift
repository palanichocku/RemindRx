//
//  WeekdayButtonView.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/5/25.
//

import SwiftUI

struct WeekdayButtonView: View {
    let day: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(day.prefix(1))
                .font(.system(size: 14, weight: .medium))
                .frame(width: 30, height: 30)
                .background(isSelected ? AppColors.primaryFallback() : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Circle())
        }
        .buttonStyle(FixedButtonStyle()) // Use a more reliable button style
    }
}

// A fixed button style that doesn't interfere with other gestures
struct FixedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}
