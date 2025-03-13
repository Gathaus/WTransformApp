//
//  SettingsView.swift
//  WTransform
//
//  Created by Trae AI on 15.03.2025.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var subscriptionService: SubscriptionService
    @State private var showingSubscriptionView = false
    @State private var showingPrivacyPolicy = false
    @State private var showingTerms = false
    @State private var showingFeedback = false
    @State private var autosaveToPhotos = true
    @State private var defaultTransitionStyle: TransitionStyle = .crossFade
    @State private var defaultSpeed: VideoCreationView.VideoSpeed = .normal
    @State private var highQualityExport = false
    @State private var includeDate = true
    
    var body: some View {
        NavigationView {
            List {
                // Subscription Section
                Section(header: Text("Subscription").textCase(.uppercase)) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Current Plan")
                                .font(.headline)
                            
                            Spacer()
                            
                            Text(subscriptionService.currentTier.rawValue)
                                .foregroundColor(.blue)
                                .fontWeight(.semibold)
                        }
                        
                        if subscriptionService.isTrialActive, let days = subscriptionService.remainingDaysInTrial() {
                            Text("\(days) \(days == 1 ? "day" : "days") remaining in Free Premium")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        if subscriptionService.currentTier == .free {
                            Text("\(subscriptionService.videosCreatedCount)/3 free videos created")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.bottom, 5)
                        }
                        
                        if subscriptionService.currentTier != .professional {
                            Button(action: {
                                showingSubscriptionView = true
                            }) {
                                Text(subscriptionService.currentTier == .free ? "Upgrade to Premium" : "Manage Subscription")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 15)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.vertical, 5)
                }
                
                // Video Settings Section
                Section(header: Text("Video Settings").textCase(.uppercase)) {
                    Toggle("Auto-save to Photos", isOn: $autosaveToPhotos)
                    
                    Picker("Default Transition", selection: $defaultTransitionStyle) {
                        ForEach(TransitionStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    
                    Picker("Default Speed", selection: $defaultSpeed) {
                        ForEach(VideoCreationView.VideoSpeed.allCases) { speed in
                            Text(speed.rawValue).tag(speed)
                        }
                    }
                    
                    Toggle("Include Date on Videos", isOn: $includeDate)
                    
                    if subscriptionService.currentTier == .premium || subscriptionService.currentTier == .professional {
                        Toggle("High Quality Export", isOn: $highQualityExport)
                    } else {
                        HStack {
                            Text("High Quality Export")
                            Spacer()
                            Text("Premium Feature")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // App Section
                Section(header: Text("Application").textCase(.uppercase)) {
                    Button(action: {
                        // Rate app
                    }) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("Rate the App")
                        }
                    }
                    
                    Button(action: {
                        showingFeedback = true
                    }) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.blue)
                            Text("Send Feedback")
                        }
                    }
                    
                    Button(action: {
                        showingPrivacyPolicy = true
                    }) {
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.gray)
                            Text("Privacy Policy")
                        }
                    }
                    
                    Button(action: {
                        showingTerms = true
                    }) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.gray)
                            Text("Terms of Service")
                        }
                    }
                }
                
                Section {
                    // Add app version at the bottom
                    HStack {
                        Spacer()
                        VStack(spacing: 5) {
                            Text("WTransform")
                                .font(.headline)
                            Text("Version 1.0.0")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 10)
                }
                .listRowBackground(Color.clear)
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Settings")
            .sheet(isPresented: $showingSubscriptionView) {
                SubscriptionView(subscriptionService: subscriptionService)
            }
            .sheet(isPresented: $showingPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .sheet(isPresented: $showingTerms) {
                TermsOfServiceView()
            }
            .sheet(isPresented: $showingFeedback) {
                FeedbackView()
            }
        }
    }
}

// Supporting Views

struct PrivacyPolicyView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    Text("Privacy Policy")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.bottom, 5)
                    
                    Group {
                        Text("Last updated: March 15, 2025")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 20)
                        
                        Text("1. Information We Collect")
                            .font(.headline)
                            .padding(.vertical, 5)
                        
                        Text("WTransform may collect the following information:")
                            .padding(.bottom, 5)
                        
                        BulletPoint(text: "Media files you choose to transform")
                        BulletPoint(text: "App usage data to improve your experience")
                        BulletPoint(text: "Device information for troubleshooting")
                    }
                    
                    Group {
                        Text("2. How We Use Your Information")
                            .font(.headline)
                            .padding(.vertical, 5)
                        
                        BulletPoint(text: "To provide and improve our services")
                        BulletPoint(text: "To process your subscription")
                        BulletPoint(text: "To respond to your requests and inquiries")
                    }
                    
                    Group {
                        Text("3. Data Security")
                            .font(.headline)
                            .padding(.vertical, 5)
                        
                        Text("We implement appropriate security measures to protect your personal information. However, no method of transmission over the Internet or electronic storage is 100% secure.")
                    }
                    
                    Group {
                        Text("4. Changes to This Policy")
                            .font(.headline)
                            .padding(.vertical, 5)
                        
                        Text("We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page.")
                    }
                    
                    Group {
                        Text("5. Contact Us")
                            .font(.headline)
                            .padding(.vertical, 5)
                        
                        Text("If you have any questions about this Privacy Policy, please contact us at:")
                            .padding(.bottom, 5)
                        
                        Text("support@wtransform.com")
                            .foregroundColor(.blue)
                    }
                }
                .padding()
            }
            .navigationBarTitle("Privacy Policy", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                // Close sheet
            })
        }
    }
}

struct BulletPoint: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text("•")
                .padding(.trailing, 5)
            Text(text)
            Spacer()
        }
        .padding(.leading, 10)
        .padding(.bottom, 5)
    }
}

struct TermsOfServiceView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    Text("Terms of Service")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.bottom, 5)
                    
                    Text("Last updated: March 15, 2025")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 20)
                    
                    Text("By downloading, installing, or using WTransform, you agree to be bound by these Terms of Service.")
                        .padding(.bottom, 10)
                    
                    // Content sections similar to privacy policy...
                    Group {
                        Text("1. License")
                            .font(.headline)
                            .padding(.vertical, 5)
                        
                        Text("WTransform grants you a limited, non-exclusive, non-transferable, revocable license to use the app for your personal, non-commercial purposes.")
                    }
                    
                    Group {
                        Text("2. Subscriptions")
                            .font(.headline)
                            .padding(.vertical, 5)
                        
                        Text("Some features of WTransform require a subscription. Subscriptions automatically renew unless auto-renew is turned off at least 24 hours before the end of the current period.")
                        
                        Text("You can manage and cancel your subscriptions by going to your account settings on the App Store after purchase.")
                            .padding(.top, 5)
                    }
                    
                    // Additional sections...
                }
                .padding()
            }
            .navigationBarTitle("Terms of Service", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                // Close sheet
            })
        }
    }
}

struct FeedbackView: View {
    @State private var feedbackText = ""
    @State private var feedbackType = "Bug Report"
    @State private var contactEmail = ""
    @State private var isSubmitting = false
    @State private var showingSuccess = false
    
    let feedbackTypes = ["Bug Report", "Feature Request", "General Feedback"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Feedback Type")) {
                    Picker("Type", selection: $feedbackType) {
                        ForEach(feedbackTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Your Feedback")) {
                    TextEditor(text: $feedbackText)
                        .frame(minHeight: 150)
                    
                    TextField("Your Email (Optional)", text: $contactEmail)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                
                Section {
                    Button(action: submitFeedback) {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Submit Feedback")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .disabled(feedbackText.isEmpty || isSubmitting)
                }
            }
            .navigationTitle("Send Feedback")
            .navigationBarItems(trailing: Button("Cancel") {
                // Close sheet
            })
            .alert(isPresented: $showingSuccess) {
                Alert(
                    title: Text("Thank You!"),
                    message: Text("Your feedback has been submitted successfully."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    func submitFeedback() {
        isSubmitting = true
        
        // Simulate network request
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSubmitting = false
            showingSuccess = true
            feedbackText = ""
            contactEmail = ""
        }
    }
} 