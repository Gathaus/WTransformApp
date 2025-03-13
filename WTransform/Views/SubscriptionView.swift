//
//  SubscriptionView.swift
//  WTransform
//
//  Created by Trae AI on 15.03.2025.
//

import SwiftUI

struct SubscriptionView: View {
    @ObservedObject var subscriptionService: SubscriptionService
    @State private var selectedTier: SubscriptionTier = .basic
    @State private var isLoading = false
    @State private var showingSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingRestoreMessage = false
    @State private var restoreMessage = ""
    @State private var isPresentingMainApp = false

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.purple.opacity(0.7)]), 
                               startPoint: .top, 
                               endPoint: .bottom)
                    .edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Header
                        headerView
                        
                        // Benefits
                        benefitsView
                        
                        // Subscription tiers
                        tiersView
                        
                        // Calls to action
                        actionButtonsView
                        
                        // Fine print
                        legalTextView
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarItems(trailing: closeButton)
            .alert(isPresented: $showingError) {
                Alert(
                    title: Text("Subscription Error"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .fullScreenCover(isPresented: $isPresentingMainApp, content: {
                MainTabView(subscriptionService: subscriptionService)
            })
        }
    }
    
    // Close button that appears if user has active trial or subscription
    var closeButton: some View {
        Group {
            if subscriptionService.isTrialActive || subscriptionService.hasActiveSubscription() {
                Button(action: {
                    isPresentingMainApp = true
                }) {
                    Text("Continue")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            } else {
                EmptyView()
            }
        }
    }
    
    var headerView: some View {
        VStack(spacing: 20) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 60))
                .foregroundColor(.white)
                .padding(.top, 30)
            
            Text("WTransform Premium")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Create Amazing Transformation Videos")
                .font(.title3)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    var benefitsView: some View {
        VStack(spacing: 15) {
            BenefitRow(icon: "film", title: "Unlimited Videos", description: "Create as many videos as you want")
            BenefitRow(icon: "wand.and.stars.inverse", title: "Premium Effects", description: "Access to all transitions and effects")
            BenefitRow(icon: "arrow.up.square", title: "4K Export", description: "Export videos in ultra-high quality")
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.15))
        )
        .padding(.horizontal)
    }
    
    var tiersView: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Choose Your Plan")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            ForEach(SubscriptionTier.allCases.filter { $0 != .free }, id: \.self) { tier in
                SubscriptionTierRow(
                    tier: tier,
                    isSelected: selectedTier == tier,
                    action: { selectedTier = tier }
                )
            }
        }
    }
    
    var actionButtonsView: some View {
        VStack(spacing: 15) {
            // Subscribe button
            Button(action: purchaseSubscription) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color.white.opacity(0.3))
                        .cornerRadius(15)
                } else {
                    Text("Subscribe Now \(formatPrice(selectedTier.price))/month")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color.purple)
                        .cornerRadius(15)
                        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
                }
            }
            .disabled(isLoading)
            
            // Restore purchases button
            Button(action: restorePurchases) {
                Text("Restore Purchases")
                    .font(.subheadline)
                    .underline()
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.top, 5)
            }
            .disabled(isLoading)
            
            if showingRestoreMessage {
                Text(restoreMessage)
                    .font(.caption)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.top, 5)
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }
    
    var legalTextView: some View {
        VStack(spacing: 10) {
            Text("Subscription automatically renews unless auto-renew is turned off at least 24 hours before the end of the current period. Manage subscriptions in Account Settings.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.top, 20)
            
            HStack {
                Button(action: {
                    // Open Privacy Policy
                }) {
                    Text("Privacy Policy")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                        .underline()
                }
                
                Text("•")
                    .foregroundColor(.white.opacity(0.7))
                
                Button(action: {
                    // Open Terms of Service
                }) {
                    Text("Terms of Service")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                        .underline()
                }
            }
        }
    }
    
    // MARK: - Action Methods
    
    private func purchaseSubscription() {
        isLoading = true
        
        subscriptionService.purchaseSubscription(selectedTier) { success, error in
            isLoading = false
            
            if success {
                showingSuccess = true
                isPresentingMainApp = true
            } else if let error = error {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func restorePurchases() {
        isLoading = true
        showingRestoreMessage = false
        
        subscriptionService.restorePurchases { success, error in
            isLoading = false
            
            if success {
                isPresentingMainApp = true
            } else {
                restoreMessage = error?.localizedDescription ?? "No previous purchases found"
                showingRestoreMessage = true
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatPrice(_ price: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        
        return formatter.string(from: price as NSDecimalNumber) ?? "$\(price)"
    }
}

// MARK: - Supporting Views

struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.purple.opacity(0.5)))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
        }
    }
}

struct SubscriptionTierRow: View {
    let tier: SubscriptionTier
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(tier.rawValue)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(formatPrice(tier.price) + "/month")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                    
                    ForEach(tier.features.prefix(2), id: \.self) { feature in
                        Label {
                            Text(feature)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        } icon: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 12))
                        }
                        .padding(.top, 2)
                    }
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                    .font(.title3)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.purple.opacity(0.7) : Color.white.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
                    )
            )
            .padding(.horizontal)
        }
    }
    
    private func formatPrice(_ price: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        
        return formatter.string(from: price as NSDecimalNumber) ?? "$\(price)"
    }
}

// Placeholder for Main Tab View - to be replaced with actual implementation
struct MainTabView: View {
    let subscriptionService: SubscriptionService
    
    var body: some View {
        ContentView()
            .environmentObject(subscriptionService)
            .environmentObject(PhotoService())
    }
} 