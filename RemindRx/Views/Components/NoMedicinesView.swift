//
//  NoMedicineView.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/5/25.
//

import SwiftUI

struct NoMedicinesView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "pills")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Medicines Added")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("Add medicines to your collection first before creating medication schedules")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            NavigationLink(destination: MedicineListView()) {
                Text("Go to Medicines")
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppColors.primaryFallback())
                    .cornerRadius(8)
            }
            .padding(.top, 20)
        }
        .padding()
    }
}
