//
//  OnboardingView.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/17/25.
//

import SwiftUI

struct OnboardingView: View {
    @Binding var isShowingOnboarding: Bool
    @State private var currentPage = 0
    
    // Define onboarding pages
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Welcome to RemindRx",
            description: "Track your medicine expiration dates and get timely reminders before they expire.",
            imageName: "heart.text.square.fill",
            imageColor: .blue
        ),
        OnboardingPage(
            title: "Scan Barcodes",
            description: "The fastest way to add medicines is by scanning the barcode. Most medicine packages have barcodes that can be easily scanned.",
            imageName: "barcode.viewfinder",
            imageColor: .blue,
            isRecommended: true
        ),
        OnboardingPage(
            title: "OCR Scanning (Backup)",
            description: "If the barcode can't be scanned, you can use OCR to capture text from the medicine packaging in two steps.",
            imageName: "text.viewfinder",
            imageColor: .orange,
            isBackup: true
        ),
        OnboardingPage(
            title: "Manual Entry",
            description: "If scanning options don't work, you can always add medicines manually by entering the details yourself.",
            imageName: "keyboard",
            imageColor: .purple,
            isBackup: true
        ),
        OnboardingPage(
            title: "Get Reminders",
            description: "RemindRx will notify you before your medicines expire, so you can always keep your medicine cabinet up to date.",
            imageName: "bell.fill",
            imageColor: .green
        )
    ]
    
    var body: some View {
        ZStack {
            // Background color
            Color(.systemGroupedBackground)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                // Skip button
                HStack {
                    Spacer()
                    Button("Skip") {
                        isShowingOnboarding = false
                    }
                    .padding()
                    .foregroundColor(.secondary)
                }
                
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        pageView(for: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                
                // Next/Get Started button
                Button(action: {
                    if currentPage < pages.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        isShowingOnboarding = false
                    }
                }) {
                    Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
    }
    
    private func pageView(for page: OnboardingPage) -> some View {
        VStack(spacing: 25) {
            Spacer()
            
            // Image
            Image(systemName: page.imageName)
                .font(.system(size: 100))
                .foregroundColor(page.imageColor)
                .padding()
            
            // Title
            Text(page.title)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Recommendation badge if applicable
            if page.isRecommended {
                Text("RECOMMENDED METHOD")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(5)
            } else if page.isBackup {
                Text("BACKUP METHOD")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(5)
            }
            
            // Description
            Text(page.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
                .padding(.top, page.isRecommended || page.isBackup ? 10 : 0)
            
            Spacer()
            Spacer()
        }
        .padding()
    }
}

struct OnboardingPage {
    let title: String
    let description: String
    let imageName: String
    let imageColor: Color
    var isRecommended: Bool = false
    var isBackup: Bool = false
}
