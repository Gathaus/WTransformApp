//
//  PhotoService.swift
//  WTransform
//
//  Created by Trae AI on 9.03.2025.
//

import SwiftUI
import AVFoundation
import Photos

// MARK: - Models
struct CapturedImage: Identifiable {
    let id: String
    let date: Date
    let url: URL
}

// MARK: - Photo Service Protocol
protocol PhotoServiceProtocol: AnyObject {
    var capturedImages: [CapturedImage] { get }
    var cameraPermissionGranted: Bool { get }
    var photoLibraryPermissionGranted: Bool { get }
    
    func requestPermissions()
    func loadSavedImages()
    func saveImage(_ image: UIImage)
    func createVideo(from images: [CapturedImage], completion: @escaping (URL?, Error?) -> Void)
    func saveVideoToLibrary(url: URL, completion: @escaping (Bool, Error?) -> Void)
}

// MARK: - Photo Service Implementation
class PhotoService: ObservableObject, PhotoServiceProtocol {
    @Published var capturedImages: [CapturedImage] = []
    @Published var cameraPermissionGranted = false
    @Published var photoLibraryPermissionGranted = false
    
    init() {
        loadSavedImages()
    }
    
    func requestPermissions() {
        // Check current camera permission status first
        if AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
            DispatchQueue.main.async {
                self.cameraPermissionGranted = true
            }
        } else {
            // Request access only if not already authorized
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.cameraPermissionGranted = granted
                }
            }
        }
        
        // Check current photo library permission status
        if PHPhotoLibrary.authorizationStatus() == .authorized {
            DispatchQueue.main.async {
                self.photoLibraryPermissionGranted = true
            }
        } else {
            // Request access only if not already authorized
            PHPhotoLibrary.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    self?.photoLibraryPermissionGranted = status == .authorized
                }
            }
        }
    }
    
    func loadSavedImages() {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let transformDirectory = documentsDirectory.appendingPathComponent("TransformPhotos")
        
        do {
            // Create directory if it doesn't exist
            if !fileManager.fileExists(atPath: transformDirectory.path) {
                try fileManager.createDirectory(at: transformDirectory, withIntermediateDirectories: true)
                return // No images yet
            }
            
            let fileURLs = try fileManager.contentsOfDirectory(at: transformDirectory, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
            
            self.capturedImages = fileURLs.compactMap { url in
                guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
                      let creationDate = attributes[.creationDate] as? Date,
                      url.pathExtension.lowercased() == "jpeg" else {
                    return nil
                }
                
                return CapturedImage(id: url.lastPathComponent, date: creationDate, url: url)
            }
            .sorted(by: { $0.date > $1.date })
            
        } catch {
            print("Error loading saved images: \(error)")
        }
    }
    
    func saveImage(_ image: UIImage) {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let transformDirectory = documentsDirectory.appendingPathComponent("TransformPhotos")
        
        do {
            // Create directory if it doesn't exist
            if !fileManager.fileExists(atPath: transformDirectory.path) {
                try fileManager.createDirectory(at: transformDirectory, withIntermediateDirectories: true)
            }
            
            // Create file name with date
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
            let fileName = "transform_\(dateFormatter.string(from: Date())).jpeg"
            let fileURL = transformDirectory.appendingPathComponent(fileName)
            
            // Save image
            if let jpegData = image.jpegData(compressionQuality: 0.8) {
                try jpegData.write(to: fileURL)
                
                // Add to captured images
                let newImage = CapturedImage(id: fileName, date: Date(), url: fileURL)
                DispatchQueue.main.async {
                    self.capturedImages.insert(newImage, at: 0)
                }
            }
        } catch {
            print("Error saving image: \(error)")
        }
    }
    
    func createVideo(from images: [CapturedImage], completion: @escaping (URL?, Error?) -> Void) {
        guard !images.isEmpty else {
            completion(nil, NSError(domain: "WTransform", code: 1, userInfo: [NSLocalizedDescriptionKey: "No images available"]))
            return
        }
        
        // Sort images by date (oldest first)
        let sortedImages = images.sorted(by: { $0.date < $1.date })
        
        // Video settings
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 1080,
            AVVideoHeightKey: 1920
        ]
        
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let videoURL = documentsDirectory.appendingPathComponent("transform_\(dateFormatter.string(from: Date())).mp4")
        
        do {
            // Delete existing file if exists
            if fileManager.fileExists(atPath: videoURL.path) {
                try fileManager.removeItem(at: videoURL)
            }
            
            // Create video writer
            let videoWriter = try AVAssetWriter(outputURL: videoURL, fileType: .mp4)
            let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: videoWriterInput,
                sourcePixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                    kCVPixelBufferWidthKey as String: 1080,
                    kCVPixelBufferHeightKey as String: 1920
                ]
            )
            
            videoWriterInput.expectsMediaDataInRealTime = false
            videoWriter.add(videoWriterInput)
            
            // Start writing
            videoWriter.startWriting()
            videoWriter.startSession(atSourceTime: .zero)
            
            // Frame duration (2 seconds per image)
            let frameDuration = CMTimeMake(value: 2, timescale: 1)
            var frameCount = 0
            
            // Process each image
            for (index, capturedImage) in sortedImages.enumerated() {
                autoreleasepool {
                    guard let uiImage = UIImage(contentsOfFile: capturedImage.url.path) else { return }
                    
                    // Scale image to video dimensions
                    let resizedImage = uiImage.resizeTo(size: CGSize(width: 1080, height: 1920))
                    
                    // Wait for writer to be ready
                    while !videoWriterInput.isReadyForMoreMediaData {
                        Thread.sleep(forTimeInterval: 0.1)
                    }
                    
                    // Create pixel buffer
                    if let pixelBuffer = resizedImage.pixelBuffer(width: 1080, height: 1920) {
                        // Add pixel buffer to the video
                        let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(frameCount))
                        pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                        frameCount += 1
                    }
                    
                    // Add a crossfade between images if not the last image
                    if index < sortedImages.count - 1 {
                        guard let nextUIImage = UIImage(contentsOfFile: sortedImages[index + 1].url.path) else { return }
                        let nextResizedImage = nextUIImage.resizeTo(size: CGSize(width: 1080, height: 1920))
                        
                        // Create 10 frames for transition (0.5 seconds)
                        for j in 1...10 {
                            let alpha = CGFloat(j) / 10.0
                            if let blendedImage = resizedImage.blend(with: nextResizedImage, alpha: alpha),
                               let pixelBuffer = blendedImage.pixelBuffer(width: 1080, height: 1920) {
                                let presentationTime = CMTimeAdd(
                                    CMTimeMultiply(frameDuration, multiplier: Int32(frameCount)),
                                    CMTimeMake(value: Int64(j), timescale: 20) // 1/20 second increments
                                )
                                pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                                frameCount += 1
                            }
                        }
                    }
                }
            }
            
            // Finalize writing
            videoWriterInput.markAsFinished()
            videoWriter.finishWriting {
                if videoWriter.status == .completed {
                    completion(videoURL, nil)
                } else {
                    completion(nil, videoWriter.error)
                }
            }
        } catch {
            completion(nil, error)
        }
    }
    
    func saveVideoToLibrary(url: URL, completion: @escaping (Bool, Error?) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: url, options: nil)
        }) { success, error in
            completion(success, error)
        }
    }
}