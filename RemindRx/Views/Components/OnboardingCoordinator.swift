//
//  OnboardingCoordinator.swift
//  RemindRx
//
//  Created by Palam Chocku on 3/17/25.
//

import SwiftUI
import Combine

// Coordinator to manage onboarding state
class OnboardingCoordinator: ObservableObject {
    @Published var shouldShowOnboarding: Bool
    
    private let onboardingShownKey = "hasShownOnboarding"
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Check if we've shown onboarding before
        self.shouldShowOnboarding = !UserDefaults.standard.bool(forKey: onboardingShownKey)
        
        // When onboarding is dismissed, save that we've shown it
        $shouldShowOnboarding
            .dropFirst() // Skip initial value
            .sink { [weak self] showOnboarding in
                if !showOnboarding {
                    self?.markOnboardingAsShown()
                }
            }
            .store(in: &cancellables)
    }
    
    func markOnboardingAsShown() {
        UserDefaults.standard.set(true, forKey: onboardingShownKey)
    }
    
    func resetOnboarding() {
        UserDefaults.standard.set(false, forKey: onboardingShownKey)
        shouldShowOnboarding = true
    }
}
