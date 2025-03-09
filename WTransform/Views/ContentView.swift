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
    @StateObject private var photoService = PhotoService()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            CameraView(photoManager: photoService)
                .tabItem {
                    Label("Take Photo", systemImage: "camera")
                }
                .tag(0)
            
            PhotoGalleryView(photoManager: photoService)
                .tabItem {
                    Label("Photos", systemImage: "photo.on.rectangle")
                }
                .tag(1)
            
            VideoCreationView(photoManager: photoService)
                .tabItem {
                    Label("Create Video", systemImage: "play.rectangle")
                }
                .tag(2)
        }
        .onAppear {
            photoService.requestPermissions()
        }
    }
}

#Preview {
    ContentView()
}