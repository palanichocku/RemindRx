//
//  ComingSoonFeatureView.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/11/25.
//
import SwiftUI

// Create a standalone navigation view for the Coming Soon feature
struct ComingSoonFeatureView: View {
    @Environment(\.presentationMode) var presentationMode
    let featureName: String
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Icon
                Image(systemName: "hammer.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.orange)
                    .padding(.top, 40)
                
                // Title
                Text("Coming Soon")
                    .font(.title)
                    .fontWeight(.bold)
                
                // Message
                Text("\(featureName) feature is currently under development and will be available in a future update.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                
                Spacer()
                
                // Close button
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Text("Close")
                        .fontWeight(.medium)
                        .padding(.horizontal, 50)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.bottom, 40)
            }
            .padding()
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarItems(trailing:
                Button("Dismiss") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}
