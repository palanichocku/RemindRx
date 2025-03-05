//
//  EmptyMedicinesView.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/5/25.
//

import SwiftUI

// View for when no medicines are available
struct EmptyMedicinesView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "pills")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("No medicines added")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("Scan a medicine barcode to add it to your collection")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}
