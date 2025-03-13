//
//  SubscriptionService.swift
//  WTransform
//
//  Created by Trae AI on 15.03.2025.
//

import Foundation
import StoreKit

// MARK: - Subscription Models
enum SubscriptionTier: String, CaseIterable {
    case free = "Free"
    case basic = "Basic"
    case premium = "Premium"
    case professional = "Professional"
    
    var features: [String] {
        switch self {
        case .free:
            return ["Create up to 3 videos", "Basic transitions", "Standard quality"]
        case .basic:
            return ["Unlimited videos", "All transitions", "HD quality", "Remove watermark"]
        case .premium:
            return ["All Basic features", "Premium effects", "Advanced filters", "No date label", "Cloud backup"]
        case .professional:
            return ["All Premium features", "4K video export", "Custom watermark", "Priority support", "Commercial usage license"]
        }
    }
    
    var price: Decimal {
        switch self {
        case .free: return 0
        case .basic: return 3.99
        case .premium: return 7.99
        case .professional: return 14.99
        }
    }
    
    var id: String {
        switch self {
        case .free: return "com.transform.free"
        case .basic: return "com.transform.basic.monthly"
        case .premium: return "com.transform.premium.monthly"
        case .professional: return "com.transform.professional.monthly"
        }
    }
}

// MARK: - Subscription Service Protocol
protocol SubscriptionServiceProtocol {
    var currentTier: SubscriptionTier { get }
    var isTrialActive: Bool { get }
    var trialEndDate: Date? { get }
    var videosCreatedCount: Int { get }
    
    func startTrial()
    func purchaseSubscription(_ tier: SubscriptionTier, completion: @escaping (Bool, Error?) -> Void)
    func restorePurchases(completion: @escaping (Bool, Error?) -> Void)
    func incrementVideosCreated()
    func canCreateMoreVideos() -> Bool
    func remainingDaysInTrial() -> Int?
    func hasActiveSubscription() -> Bool
}

// MARK: - Subscription Service Implementation
class SubscriptionService: ObservableObject, SubscriptionServiceProtocol {
    @Published var currentTier: SubscriptionTier = .free
    @Published var isTrialActive: Bool = false
    @Published var trialEndDate: Date?
    @Published var videosCreatedCount: Int = 0
    
    private let userDefaults = UserDefaults.standard
    private let trialLengthDays = 3
    private let maximumFreeVideos = 3
    
    private enum UserDefaultsKeys {
        static let trialStartDate = "trialStartDate"
        static let trialEndDate = "trialEndDate"
        static let isTrialActive = "isTrialActive"
        static let currentTier = "currentTier"
        static let videosCreatedCount = "videosCreatedCount"
        static let firstLaunch = "firstLaunch"
    }
    
    init() {
        loadSubscriptionStatus()
        
        // Check if this is the first launch
        if !userDefaults.bool(forKey: UserDefaultsKeys.firstLaunch) {
            userDefaults.set(true, forKey: UserDefaultsKeys.firstLaunch)
            userDefaults.set(0, forKey: UserDefaultsKeys.videosCreatedCount)
        }
    }
    
    private func loadSubscriptionStatus() {
        // Load subscription tier
        if let tierString = userDefaults.string(forKey: UserDefaultsKeys.currentTier),
           let tier = SubscriptionTier(rawValue: tierString) {
            self.currentTier = tier
        }
        
        // Load trial status
        isTrialActive = userDefaults.bool(forKey: UserDefaultsKeys.isTrialActive)
        if let endDate = userDefaults.object(forKey: UserDefaultsKeys.trialEndDate) as? Date {
            trialEndDate = endDate
            
            // Check if trial has expired
            if Date() > endDate {
                isTrialActive = false
                userDefaults.set(false, forKey: UserDefaultsKeys.isTrialActive)
            }
        }
        
        // Load videos created count
        videosCreatedCount = userDefaults.integer(forKey: UserDefaultsKeys.videosCreatedCount)
    }
    
    func startTrial() {
        guard !isTrialActive && trialEndDate == nil else { return }
        
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: trialLengthDays, to: startDate)!
        
        isTrialActive = true
        trialEndDate = endDate
        
        userDefaults.set(startDate, forKey: UserDefaultsKeys.trialStartDate)
        userDefaults.set(endDate, forKey: UserDefaultsKeys.trialEndDate)
        userDefaults.set(true, forKey: UserDefaultsKeys.isTrialActive)
    }
    
    func purchaseSubscription(_ tier: SubscriptionTier, completion: @escaping (Bool, Error?) -> Void) {
        // In a real app, this would connect to StoreKit to process the payment
        
        // Mock successful purchase for now
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.currentTier = tier
            self.userDefaults.set(tier.rawValue, forKey: UserDefaultsKeys.currentTier)
            completion(true, nil)
        }
    }
    
    func restorePurchases(completion: @escaping (Bool, Error?) -> Void) {
        // In a real app, this would connect to StoreKit to restore previous purchases
        
        // Mock restore for now
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(false, NSError(domain: "WTransform", code: 0, userInfo: [NSLocalizedDescriptionKey: "No previous purchases found"]))
        }
    }
    
    func incrementVideosCreated() {
        videosCreatedCount += 1
        userDefaults.set(videosCreatedCount, forKey: UserDefaultsKeys.videosCreatedCount)
    }
    
    func canCreateMoreVideos() -> Bool {
        // If user has an active subscription or trial, they can create unlimited videos
        if hasActiveSubscription() || isTrialActive {
            return true
        }
        
        // If user is on free tier, limit the number of videos
        return videosCreatedCount < maximumFreeVideos
    }
    
    func remainingDaysInTrial() -> Int? {
        guard isTrialActive, let endDate = trialEndDate else {
            return nil
        }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: endDate)
        return components.day
    }
    
    func hasActiveSubscription() -> Bool {
        return currentTier != .free
    }
    
    // MARK: - Helper Methods for In-App Purchase (for real implementation)
    
    func setupStoreKitObserver() {
        // In real app, setup StoreKit transaction observer here
    }
    
    func validateReceipt() {
        // In real app, verify purchase receipts with App Store server
    }
} 