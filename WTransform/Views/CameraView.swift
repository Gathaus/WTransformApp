//
//  CameraView.swift
//  WTransform
//
//  Created by Trae AI on 9.03.2025.
//

import SwiftUI
import AVFoundation
// Bu importu silebiliriz, aşağıdaki satırı ekleyeceğiz
// import WTransform

struct CameraView: View {
    @ObservedObject var photoManager: PhotoService
    @StateObject private var cameraService = CameraService()
    @State private var showingCaptureAnimation = false
    @State private var lastImageTaken: UIImage?
    @State private var showingLastImage = false
    
    var body: some View {
        ZStack {
            // Camera preview
            if cameraService.isCameraReady {
                CameraPreview(cameraService: cameraService)
                    .edgesIgnoringSafeArea(.all)
                
                // Controls overlay
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        // Last photo thumbnail button
                        if let lastImage = photoManager.capturedImages.first {
                            Button(action: {
                                showingLastImage = true
                            }) {
                                AsyncImage(url: lastImage.url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Color.gray
                                }
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white, lineWidth: 2))
                                .padding()
                            }
                        }
                        
                        Spacer()
                        
                        // Capture button
                        Button(action: {
                            // Force start session if not running
                            if !cameraService.isSessionRunning {
                                cameraService.startSession()
                                // Add a small delay before capture
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    capturePhoto()
                                }
                            } else {
                                capturePhoto()
                            }
                        }) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 70, height: 70)
                                .overlay(Circle().stroke(Color.black.opacity(0.2), lineWidth: 2))
                                .shadow(radius: 5)
                                .padding()
                        }
                        
                        Spacer()
                        
                        // Flip camera button
                        Button(action: {
                            cameraService.switchCamera()
                        }) {
                            Image(systemName: "arrow.triangle.2.circlepath.camera")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                                .padding()
                        }
                        
                        Spacer()
                    }
                    .padding(.bottom, 20)
                }
            } else {
                // Loading or permission screen
                VStack {
                    if let error = cameraService.error {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                        
                        Button("Go to Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    } else {
                        ProgressView()
                        Text("Starting camera...")
                            .padding()
                    }
                }
                // Set background to black to prevent white screen
                .background(Color.black)
                .edgesIgnoringSafeArea(.all)
            }
            
            // Flash animation when photo is taken
            if showingCaptureAnimation {
                Color.white
                    .edgesIgnoringSafeArea(.all)
                    .opacity(0.7)
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $showingLastImage) {
            if let lastImage = photoManager.capturedImages.first {
                VStack {
                    Text("Last Photo")
                        .font(.title)
                        .padding()
                    
                    Spacer()
                    
                    AsyncImage(url: lastImage.url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        ProgressView()
                    }
                    
                    Spacer()
                    
                    Text(formatDate(lastImage.date))
                        .padding()
                    
                    Button("Close") {
                        showingLastImage = false
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            cameraService.checkPermission()
        }
        .onDisappear {
            cameraService.stopSession()
        }
    }
    
    func capturePhoto() {
        cameraService.capturePhoto { image in
            if let image = image {
                photoManager.saveImage(image)
                lastImageTaken = image
                
                // Show capture animation
                withAnimation {
                    showingCaptureAnimation = true
                }
                
                // Hide animation after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation {
                        showingCaptureAnimation = false
                    }
                }
            }
        }
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var cameraService: CameraService
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .black
        
        // Add the preview layer immediately
        cameraService.preview.frame = view.bounds
        cameraService.preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(cameraService.preview)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update the preview layer frame if needed
        DispatchQueue.main.async {
            cameraService.preview.frame = uiView.bounds
            
            // Ensure the session is started
            if cameraService.isCameraReady && !cameraService.isSessionRunning {
                cameraService.startSession()
            }
        }
    }
}
