//
//  WTransformApp.swift
//  WTransform
//
//  Created by Rıza Mert Yağcı on 9.03.2025.
//

import SwiftUI

@main
struct WTransformApp: App {
    // Initialize PhotoService at app launch
    @StateObject private var photoService = PhotoService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Request permissions when app launches
                    photoService.requestPermissions()
                }
        }
    }
}
