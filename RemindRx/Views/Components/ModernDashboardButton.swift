//
//  ModernDashboardButton.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/17/25.
//

import SwiftUI

struct ModernDashboardButton: View {
    let title: String
    let icon: String
    let iconColor: Color
    let action: () -> Void
    let isComingSoon: Bool
    
    init(title: String, icon: String, iconColor: Color, action: @escaping () -> Void, isComingSoon: Bool = false) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.action = action
        self.isComingSoon = isComingSoon
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                // Top part with icon
                ZStack {
                    // Background gradient
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [iconColor.opacity(0.7), iconColor.opacity(0.3)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 100)
                    
                    // Icon
                    Image(systemName: icon)
                        .font(.system(size: 36, weight: .medium))
                        .foregroundColor(.white)
                }
                
                // Bottom part with title
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            .overlay(
                // Coming soon badge
                Group {
                    if isComingSoon {
                        VStack {
                            HStack {
                                Spacer()
                                Text("SOON")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Capsule())
                                    .padding(8)
                            }
                            Spacer()
                        }
                    }
                }
            )
        }
    }
}
