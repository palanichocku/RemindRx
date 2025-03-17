//
//  QuickTipView.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/17/25.
//

import SwiftUI

// Reusable component for showing quick tips in the app
struct QuickTipView: View {
    let iconName: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    let dismissAction: () -> Void
    
    @State private var isShowingDetails = false
    
    init(
        iconName: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        dismissAction: @escaping () -> Void
    ) {
        self.iconName = iconName
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
        self.dismissAction = dismissAction
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                // Icon
                Image(systemName: iconName)
                    .font(.system(size: 28))
                    .foregroundColor(.blue)
                    .padding(.trailing, 4)
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.headline)
                        .multilineTextAlignment(.leading)
                    
                    if isShowingDetails {
                        Text(message)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity)
                    }
                }
                
                Spacer()
                
                // Info/dismiss button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        if !isShowingDetails {
                            isShowingDetails = true
                        } else {
                            dismissAction()
                        }
                    }
                }) {
                    Image(systemName: isShowingDetails ? "xmark.circle.fill" : "info.circle")
                        .foregroundColor(isShowingDetails ? .secondary : .blue)
                        .font(.system(size: 22))
                }
            }
            
            // Action Button (only show when details are shown)
            if isShowingDetails, let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .padding(.top, 4)
                .transition(.opacity)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .animation(.easeInOut(duration: 0.3), value: isShowingDetails)
    }
}
