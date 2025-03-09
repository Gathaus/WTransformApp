//
//  CameraService.swift
//  WTransform
//
//  Created by Trae AI on 9.03.2025.
//

import SwiftUI
import AVFoundation

// MARK: - Camera Service Protocol
protocol CameraServiceProtocol: AnyObject {
    var isCameraReady: Bool { get }
    var error: String? { get }
    var preview: AVCaptureVideoPreviewLayer { get }
    
    func checkPermission()
    func setupCamera()
    func startSession()
    func stopSession()
    func switchCamera()
    func capturePhoto(completion: @escaping (UIImage?) -> Void)
}

// MARK: - Camera Service Implementation
class CameraService: NSObject, ObservableObject, CameraServiceProtocol, AVCapturePhotoCaptureDelegate {
    @Published var isCameraReady = false
    @Published var error: String?
    
    var session = AVCaptureSession()
    var preview: AVCaptureVideoPreviewLayer!
    private var output = AVCapturePhotoOutput()
    private var input: AVCaptureDeviceInput!
    private var position: AVCaptureDevice.Position = .back
    private var photoCompletion: ((UIImage?) -> Void)?
    private var isSessionRunning = false
    
    override init() {
        super.init()
        // Create the preview layer immediately but don't add it to view yet
        preview = AVCaptureVideoPreviewLayer(session: session)
        // Set the background color to black to prevent white screen
        preview.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
    }
    
    deinit {
        // Make sure to stop the session when controller is deallocated
        stopSession()
    }
    
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] status in
                if status {
                    DispatchQueue.main.async {
                        self?.setupCamera()
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.error = "Kamera izni verilmedi"
                    }
                }
            }
        default:
            DispatchQueue.main.async {
                self.error = "Kamera izni verilmedi. Ayarlardan izin verebilirsiniz."
            }
        }
    }
    
    func setupCamera() {
        // Configure camera on a background thread to prevent UI freezing
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Create a new session (don't reuse the old one if there were issues)
            self.session = AVCaptureSession()
            self.preview.session = self.session
            
            do {
                // Begin configuration
                self.session.beginConfiguration()
                
                // Configure camera quality for better performance
                if self.session.canSetSessionPreset(.high) {
                    self.session.sessionPreset = .high
                }
                
                // Add input
                let cameraDevice = self.getBestCamera()
                self.input = try AVCaptureDeviceInput(device: cameraDevice)
                
                if self.session.canAddInput(self.input) {
                    self.session.addInput(self.input)
                } else {
                    throw NSError(domain: "WTransform", code: 1, userInfo: [NSLocalizedDescriptionKey: "Kamera giriş kaynağı eklenemedi"])
                }
                
                // Add output
                if self.session.canAddOutput(self.output) {
                    self.session.addOutput(self.output)
                } else {
                    throw NSError(domain: "WTransform", code: 2, userInfo: [NSLocalizedDescriptionKey: "Kamera çıkış kaynağı eklenemedi"])
                }
                
                // Commit configuration
                self.session.commitConfiguration()
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    self.isCameraReady = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.error = "Kamera ayarlanamadı: \(error.localizedDescription)"
                    print("Camera setup error: \(error)")
                }
            }
        }
    }
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        // Guard against trying to capture when session isn't running
        guard session.isRunning, isCameraReady else {
            print("Cannot capture: session not running")
            completion(nil)
            return
        }
        
        photoCompletion = completion
        
        let settings = AVCapturePhotoSettings()
        // Configure flash if needed
        settings.flashMode = .auto
        
        // Make sure we're on the main thread when calling capturePhoto
        DispatchQueue.main.async {
            self.output.capturePhoto(with: settings, delegate: self)
        }
    }
    
    func startSession() {
        // Start session on a background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, !self.isSessionRunning, self.isCameraReady else { return }
            
            self.session.startRunning()
            
            DispatchQueue.main.async {
                self.isSessionRunning = self.session.isRunning
                if !self.session.isRunning {
                    self.error = "Kamera başlatılamadı"
                }
            }
        }
    }
    
    func stopSession() {
        // Always stop session when view disappears
        if isSessionRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.stopRunning()
                
                DispatchQueue.main.async {
                    self?.isSessionRunning = false
                }
            }
        }
    }
    
    func switchCamera() {
        // Only switch if camera is ready
        guard isCameraReady else { return }
        
        // Execute on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Determine new position
            let newPosition: AVCaptureDevice.Position = (self.position == .back) ? .front : .back
            
            // Get new device
            guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
                  let newInput = try? AVCaptureDeviceInput(device: newCamera) else {
                return
            }
            
            // Update session configuration
            self.session.beginConfiguration()
            
            // Remove existing input
            if let currentInput = self.input {
                self.session.removeInput(currentInput)
            }
            
            // Add new input
            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.input = newInput
                self.position = newPosition
            }
            
            self.session.commitConfiguration()
        }
    }
    
    private func getBestCamera() -> AVCaptureDevice {
        if let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            return backCamera
        }
        
        // Fallback to front camera if back camera not available
        if let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
            return frontCamera
        }
        
        // Fallback to any available camera
        return AVCaptureDevice.default(for: .video)!
    }
    
    // MARK: - AVCapturePhotoCaptureDelegate
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
            photoCompletion?(nil)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            print("Could not get image data")
            photoCompletion?(nil)
            return
        }
        
        guard let image = UIImage(data: imageData) else {
            print("Could not create image from data")
            photoCompletion?(nil)
            return
        }
        
        // Process the image on a background thread
        DispatchQueue.global(qos: .userInitiated).async {
            // Create a properly oriented image based on metadata
            let finalImage = self.fixOrientation(image)
            
            // Return the image on the main thread
            DispatchQueue.main.async {
                self.photoCompletion?(finalImage)
            }
        }
    }
    
    // Fix image orientation based on device orientation
    private func fixOrientation(_ image: UIImage) -> UIImage {
        // If the image already has the correct orientation, return it as is
        if image.imageOrientation == .up {
            return image
        }
        
        // Otherwise, create a new image with the correct orientation
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return normalizedImage
    }
}