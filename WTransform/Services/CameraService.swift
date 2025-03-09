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
    var preview: AVCaptureVideoPreviewLayer
    private var output = AVCapturePhotoOutput()
    private var input: AVCaptureDeviceInput!
    private var position: AVCaptureDevice.Position = .back
    private var photoCompletion: ((UIImage?) -> Void)?
    @Published var isSessionRunning = false
    
    override init() {
        // Initialize preview layer in init to satisfy protocol requirement
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        // Set the background color to black to prevent white screen
        previewLayer.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        previewLayer.videoGravity = .resizeAspectFill
        preview = previewLayer
        
        super.init()
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
        // Configure camera directly on the main thread to avoid threading issues
        session = AVCaptureSession()
        preview.session = session
        
        do {
            // Begin configuration
            session.beginConfiguration()
            
            // Configure camera quality for better performance
            if session.canSetSessionPreset(.high) {
                session.sessionPreset = .high
            }
            
            // Add input
            let cameraDevice = getBestCamera()
            input = try AVCaptureDeviceInput(device: cameraDevice)
            
            if session.canAddInput(input) {
                session.addInput(input)
            } else {
                throw NSError(domain: "WTransform", code: 1, userInfo: [NSLocalizedDescriptionKey: "Kamera giriş kaynağı eklenemedi"])
            }
            
            // Add output
            if session.canAddOutput(output) {
                session.addOutput(output)
            } else {
                throw NSError(domain: "WTransform", code: 2, userInfo: [NSLocalizedDescriptionKey: "Kamera çıkış kaynağı eklenemedi"])
            }
            
            // Commit configuration
            session.commitConfiguration()
            
            // Set camera as ready
            isCameraReady = true
            
            // Start the session immediately
            startSession()
            
        } catch {
            self.error = "Kamera ayarlanamadı: \(error.localizedDescription)"
            print("Camera setup error: \(error)")
        }
    }
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        // Explicitly check if session is running
        guard isCameraReady else {
            print("Cannot capture: camera not ready")
            completion(nil)
            return
        }
        
        guard session.isRunning else {
            print("Cannot capture: session not running, trying to start now")
            startSession()
            // Give a small delay to ensure session has time to start
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.tryCapturePhoto(completion: completion)
            }
            return
        }
        
        tryCapturePhoto(completion: completion)
    }
    
    private func tryCapturePhoto(completion: @escaping (UIImage?) -> Void) {
        photoCompletion = completion
        
        let settings = AVCapturePhotoSettings()
        // Configure flash
        settings.flashMode = .auto
        
        print("Attempting to capture photo...")
        output.capturePhoto(with: settings, delegate: self)
    }
    
    func startSession() {
        guard !session.isRunning else {
            print("Session already running")
            isSessionRunning = true
            return
        }
        
        print("Starting camera session...")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            self.session.startRunning()
            
            DispatchQueue.main.async {
                self.isSessionRunning = self.session.isRunning
                print("Camera session running: \(self.session.isRunning)")
                if !self.session.isRunning {
                    self.error = "Kamera başlatılamadı"
                }
            }
        }
    }
    
    func stopSession() {
        guard session.isRunning else {
            isSessionRunning = false
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
            
            DispatchQueue.main.async {
                self?.isSessionRunning = false
                print("Camera session stopped")
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
        
        print("Photo captured successfully")
        
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
