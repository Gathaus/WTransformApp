//
//  WTransformApp.swift
//  WTransform
//
//  Created by Trae AI on 9.03.2025.
//

import SwiftUI

@main
struct WTransformApp: App {
    @StateObject private var photoService = PhotoService()
    @StateObject private var subscriptionService = SubscriptionService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(photoService)
                .environmentObject(subscriptionService)
        }
    }
}
