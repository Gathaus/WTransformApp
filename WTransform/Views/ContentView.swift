//
//  ContentView.swift
//  WTransform
//
//  Created by Trae AI on 9.03.2025.
//

import SwiftUI
import AVFoundation
import Photos

struct ContentView: View {
    @EnvironmentObject var photoService: PhotoService
    @EnvironmentObject var subscriptionService: SubscriptionService
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            CameraView(photoManager: photoService)
                .tabItem {
                    Label("Take Photo", systemImage: "camera")
                }
                .tag(0)
            
            PhotoGalleryView(photoManager: photoService, subscriptionService: subscriptionService)
                .tabItem {
                    Label("Gallery", systemImage: "photo.on.rectangle")
                }
                .tag(1)
            
            VideoCreationView(photoManager: photoService, subscriptionService: subscriptionService)
                .tabItem {
                    Label("Create Video", systemImage: "video")
                }
                .tag(2)
                
            SettingsView(subscriptionService: subscriptionService)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
        .onAppear {
            // Request permissions when view appears
            photoService.requestPermissions()
            
            // Customize tab bar appearance to make inactive tabs more visible
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.systemBackground
            
            // Customize the unselected item
            let normalAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.gray
            ]
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttributes
            appearance.stackedLayoutAppearance.normal.iconColor = UIColor.gray
            
            // Customize the selected item
            let selectedAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.systemBlue
            ]
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttributes
            appearance.stackedLayoutAppearance.selected.iconColor = UIColor.systemBlue
            
            // Apply the appearance settings
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(PhotoService())
        .environmentObject(SubscriptionService())
}
