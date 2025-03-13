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

// Video geçiş stili
enum TransitionStyle: String, CaseIterable, Identifiable {
    case crossFade = "Cross Fade"
    case slide = "Slide"
    case zoom = "Zoom"
    case wipeRight = "Wipe Right"
    case wipeLeft = "Wipe Left"
    case wipeUp = "Wipe Up"
    case wipeDown = "Wipe Down"
    case dissolve = "Dissolve"
    case pageCurl = "Page Curl"
    case ripple = "Ripple"
    case none = "None"
    
    var id: String { self.rawValue }
}

// MARK: - Photo Service Protocol
protocol PhotoServiceProtocol: AnyObject {
    var capturedImages: [CapturedImage] { get }
    var cameraPermissionGranted: Bool { get }
    var photoLibraryPermissionGranted: Bool { get }
    
    func requestPermissions()
    func loadSavedImages()
    func saveImage(_ image: UIImage)
    func createVideo(from images: [CapturedImage], duration: Double, transitionStyle: TransitionStyle, completion: @escaping (URL?, Error?) -> Void)
    func saveVideoToLibrary(url: URL, completion: @escaping (Bool, Error?) -> Void)
    func deletePhoto(_ photo: CapturedImage)
}

// MARK: - Photo Service Implementation
class PhotoService: NSObject, PhotoServiceProtocol, ObservableObject {
    // MARK: - Properties
    @Published var capturedImages: [CapturedImage] = []
    @Published var cameraPermissionGranted: Bool = false
    @Published var photoLibraryPermissionGranted: Bool = false
    
    // Document directory for saved images
    private var documentDirectory: URL? {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        checkPermissions()
    }
    
    // MARK: - Direction for Wipe Transitions
    enum WipeDirection {
        case left
        case right
        case up
        case down
    }
    
    // MARK: - Permission Methods
    private func checkPermissions() {
        requestPermissions()
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
    
    func createVideo(from images: [CapturedImage], duration: Double = 2.0, transitionStyle: TransitionStyle = .crossFade, completion: @escaping (URL?, Error?) -> Void) {
        guard !images.isEmpty else {
            DispatchQueue.main.async {
                completion(nil, NSError(domain: "WTransform", code: 1, userInfo: [NSLocalizedDescriptionKey: "No images available"]))
            }
            return
        }
        
        // Log start of process
        DispatchQueue.main.async {
            print("Video creation started with \(images.count) images")
        }
        
        // Sort images by date (oldest first)
        let sortedImages = images.sorted(by: { $0.date < $1.date })
        
        // File management
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // Create unique file name
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let videoName = "transform_\(timestamp)_\(UUID().uuidString.prefix(8)).mp4"
        let outputURL = documentsDirectory.appendingPathComponent(videoName)
        
        // Remove previous video if exists
        if fileManager.fileExists(atPath: outputURL.path) {
            do {
                try fileManager.removeItem(at: outputURL)
            } catch {
                DispatchQueue.main.async {
                    completion(nil, NSError(domain: "WTransform", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not remove existing file: \(error.localizedDescription)"]))
                }
                return
            }
        }
        
        // Create video in background thread
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // 1. Create UIImage objects
                let images: [UIImage] = try sortedImages.compactMap { capturedImage in
                    guard let uiImage = UIImage(contentsOfFile: capturedImage.url.path) else {
                        throw NSError(domain: "WTransform", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to load image from: \(capturedImage.url.path)"])
                    }
                    return uiImage
                }
                
                // 2. Video dimensions - use first photo's size
                let size = images.first?.size ?? CGSize(width: 1080, height: 1920)
                
                // 3. AVAssetWriter configuration
                guard let assetWriter = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
                    throw NSError(domain: "WTransform", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to create asset writer"])
                }
                
                // Video settings
                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: size.width,
                    AVVideoHeightKey: size.height,
                    AVVideoCompressionPropertiesKey: [
                        AVVideoAverageBitRateKey: 8_000_000,
                        AVVideoProfileLevelKey: AVVideoProfileLevelH264MainAutoLevel
                    ]
                ]
                
                // Create input
                let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                writerInput.expectsMediaDataInRealTime = false
                
                // Create adaptor
                let attributes: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                    kCVPixelBufferWidthKey as String: size.width,
                    kCVPixelBufferHeightKey as String: size.height
                ]
                
                let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                    assetWriterInput: writerInput,
                    sourcePixelBufferAttributes: attributes
                )
                
                // Add input to writer
                if assetWriter.canAdd(writerInput) {
                    assetWriter.add(writerInput)
                } else {
                    throw NSError(domain: "WTransform", code: 5, userInfo: [NSLocalizedDescriptionKey: "Cannot add input to writer"])
                }
                
                // Start writing process
                assetWriter.startWriting()
                assetWriter.startSession(atSourceTime: .zero)
                
                // Frame coordination
                let processingQueue = DispatchQueue(label: "videoProcessingQueue")
                
                // Initialize variables
                
                // Semaphore for frame synchronization
                let frameGroup = DispatchGroup()
                var error: Error?

                // Function to create pixel buffer from UIImage
                func createPixelBuffer(from image: UIImage) -> CVPixelBuffer? {
                    let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                                 kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
                    var pixelBuffer: CVPixelBuffer?
                    let status = CVPixelBufferCreate(
                        kCFAllocatorDefault,
                        Int(size.width),
                        Int(size.height),
                        kCVPixelFormatType_32ARGB,
                        attrs,
                        &pixelBuffer
                    )
                    
                    guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
                        return nil
                    }
                    
                    CVPixelBufferLockBaseAddress(buffer, [])
                    let pixelData = CVPixelBufferGetBaseAddress(buffer)
                    
                    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
                    guard let context = CGContext(
                        data: pixelData,
                        width: Int(size.width),
                        height: Int(size.height),
                        bitsPerComponent: 8,
                        bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                        space: rgbColorSpace,
                        bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
                    ) else {
                        return nil
                    }
                    
                    context.translateBy(x: 0, y: size.height)
                    context.scaleBy(x: 1, y: -1)
                    
                    UIGraphicsPushContext(context)
                    image.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
                    UIGraphicsPopContext()
                    
                    CVPixelBufferUnlockBaseAddress(buffer, [])
                    
                    return buffer
                }
                
                // Function to create slide transition
                func createSlideTransition(from firstImage: UIImage, to secondImage: UIImage, progress: CGFloat) -> UIImage? {
                    let size = firstImage.size
                    UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
                    defer { UIGraphicsEndImageContext() }
                    
                    // Draw first image sliding out
                    firstImage.draw(in: CGRect(x: -size.width * progress, y: 0, width: size.width, height: size.height))
                    
                    // Draw second image sliding in
                    secondImage.draw(in: CGRect(x: size.width * (1 - progress), y: 0, width: size.width, height: size.height))
                    
                    return UIGraphicsGetImageFromCurrentImageContext()
                }
                
                // Function to create zoom transition
                func createZoomTransition(from firstImage: UIImage, to secondImage: UIImage, progress: CGFloat) -> UIImage? {
                    let size = firstImage.size
                    UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
                    defer { UIGraphicsEndImageContext() }
                    
                    if progress < 0.5 {
                        // Zoom out first image
                        let scale = 1.0 - (progress * 0.5)
                        let scaledWidth = size.width * scale
                        let scaledHeight = size.height * scale
                        let xOffset = (size.width - scaledWidth) / 2
                        let yOffset = (size.height - scaledHeight) / 2
                        
                        firstImage.draw(in: CGRect(x: xOffset, y: yOffset, width: scaledWidth, height: scaledHeight))
                    } else {
                        // Zoom in second image
                        let adjustedProgress = (progress - 0.5) * 2 // Normalize to 0-1 range
                        let scale = 0.5 + (adjustedProgress * 0.5) // From 0.5 to 1.0
                        let scaledWidth = size.width * scale
                        let scaledHeight = size.height * scale
                        let xOffset = (size.width - scaledWidth) / 2
                        let yOffset = (size.height - scaledHeight) / 2
                        
                        secondImage.draw(in: CGRect(x: xOffset, y: yOffset, width: scaledWidth, height: scaledHeight))
                    }
                    
                    return UIGraphicsGetImageFromCurrentImageContext()
                }
                
                // Function to create wipe transition
                func createWipeTransition(from firstImage: UIImage, to secondImage: UIImage, progress: CGFloat, direction: WipeDirection) -> UIImage? {
                    let size = firstImage.size
                    UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
                    defer { UIGraphicsEndImageContext() }
                    
                    // Draw first image as background
                    firstImage.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
                    
                    // Draw second image with clip based on direction and progress
                    let context = UIGraphicsGetCurrentContext()
                    context?.saveGState()
                    
                    // Create clip rect based on direction
                    var clipRect: CGRect
                    switch direction {
                    case .right:
                        clipRect = CGRect(x: 0, y: 0, width: size.width * progress, height: size.height)
                    case .left:
                        clipRect = CGRect(x: size.width * (1 - progress), y: 0, width: size.width * progress, height: size.height)
                    case .down:
                        clipRect = CGRect(x: 0, y: 0, width: size.width, height: size.height * progress)
                    case .up:
                        clipRect = CGRect(x: 0, y: size.height * (1 - progress), width: size.width, height: size.height * progress)
                    }
                    
                    context?.clip(to: clipRect)
                    secondImage.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
                    context?.restoreGState()
                    
                    return UIGraphicsGetImageFromCurrentImageContext()
                }
                
                // Function to create dissolve transition
                func createDissolveTransition(from firstImage: UIImage, to secondImage: UIImage, progress: CGFloat) -> UIImage? {
                    // Dissolve is essentially a cross-fade with some pixelation effect
                    // For simplicity, we'll implement a more complex version of cross-fade
                    
                    let size = firstImage.size
                    UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
                    defer { UIGraphicsEndImageContext() }
                    
                    // Draw the first image
                    firstImage.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
                    
                    // Draw the second image with dissolve-like effect
                    UIGraphicsGetCurrentContext()?.setAlpha(progress)
                    secondImage.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
                    
                    return UIGraphicsGetImageFromCurrentImageContext()
                }
                
                // Function to create page curl transition
                func createPageCurlTransition(from firstImage: UIImage, to secondImage: UIImage, progress: CGFloat) -> UIImage? {
                    // Page curl is complex to implement from scratch
                    // This is a simple approximation using rotation and scaling
                    
                    let size = firstImage.size
                    UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
                    defer { UIGraphicsEndImageContext() }
                    
                    // Draw second image as background
                    secondImage.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
                    
                    if progress < 1.0 {
                        let context = UIGraphicsGetCurrentContext()
                        context?.saveGState()
                        
                        // Define a shadow for the page curl effect
                        context?.setShadow(offset: CGSize(width: 4, height: 4), blur: 5.0, color: UIColor.black.withAlphaComponent(0.5).cgColor)
                        
                        // Create a path for the curling page
                        let path = UIBezierPath()
                        path.move(to: CGPoint(x: 0, y: 0))
                        path.addLine(to: CGPoint(x: size.width * (1 - progress), y: 0))
                        path.addCurve(
                            to: CGPoint(x: size.width, y: size.height),
                            controlPoint1: CGPoint(x: size.width * (1 - progress * 0.5), y: size.height * 0.3),
                            controlPoint2: CGPoint(x: size.width * (1 - progress * 0.3), y: size.height * 0.7)
                        )
                        path.addLine(to: CGPoint(x: 0, y: size.height))
                        path.close()
                        
                        context?.addPath(path.cgPath)
                        context?.clip()
                        
                        // Draw the first image in the clipped area
                        firstImage.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
                        
                        context?.restoreGState()
                    }
                    
                    return UIGraphicsGetImageFromCurrentImageContext()
                }
                
                // Function to create ripple transition
                func createRippleTransition(from firstImage: UIImage, to secondImage: UIImage, progress: CGFloat) -> UIImage? {
                    let size = firstImage.size
                    UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
                    defer { UIGraphicsEndImageContext() }
                    
                    // Draw the background image
                    if progress < 0.5 {
                        firstImage.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
                    } else {
                        secondImage.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
                    }
                    
                    // Create ripple effect
                    let context = UIGraphicsGetCurrentContext()
                    context?.saveGState()
                    
                    // Calculate the ripple radius based on progress
                    let maxRadius = sqrt(size.width * size.width + size.height * size.height) / 2
                    let currentRadius = maxRadius * progress
                    
                    // Draw the ripple circles
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let numberOfRipples = 3
                    let rippleWidth: CGFloat = 20.0
                    
                    for i in 0..<numberOfRipples {
                        let rippleProgress = progress - (CGFloat(i) * 0.1)
                        if rippleProgress > 0 && rippleProgress < 1.0 {
                            let rippleRadius = currentRadius - (CGFloat(i) * rippleWidth)
                            if rippleRadius > 0 {
                                context?.setStrokeColor(UIColor.white.withAlphaComponent(0.5 - (0.1 * CGFloat(i))).cgColor)
                                context?.setLineWidth(rippleWidth)
                                context?.addArc(center: center, radius: rippleRadius, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
                                context?.strokePath()
                            }
                        }
                    }
                    
                    context?.restoreGState()
                    
                    return UIGraphicsGetImageFromCurrentImageContext()
                }
                
                // Initial timestamp
                var currentTime: CMTime = .zero
                
                // Process each image
                processingQueue.async {
                    for (index, image) in images.enumerated() {
                        frameGroup.enter()
                        
                        // Wait for writer to be ready
                        while !writerInput.isReadyForMoreMediaData {
                            Thread.sleep(forTimeInterval: 0.01)
                            if assetWriter.status == .failed {
                                error = assetWriter.error ?? NSError(domain: "WTransform", code: 6, userInfo: [NSLocalizedDescriptionKey: "Asset writer failed"])
                                frameGroup.leave()
                                return
                            }
                        }
                        
                        autoreleasepool {
                            // Resize image
                            let resizedImage = image.resizeTo(size: size)
                            
                            guard let pixelBuffer = createPixelBuffer(from: resizedImage) else {
                                error = NSError(domain: "WTransform", code: 7, userInfo: [NSLocalizedDescriptionKey: "Failed to create pixel buffer"])
                                frameGroup.leave()
                                return
                            }
                            
                            // Add main frame - This is the fix for first image appearing too briefly
                            adaptor.append(pixelBuffer, withPresentationTime: currentTime)
                            
                            // Each photo should have the same duration
                            let photoDuration = CMTimeMake(value: Int64(duration * 600), timescale: 600)
                            
                            // Add transition to next image if not the last one
                            if index < images.count - 1 {
                                let nextImage = images[index + 1].resizeTo(size: size)
                                
                                // Transition effect - 0.5 seconds transition duration
                                let transitionDuration = CMTimeMake(value: Int64(0.5 * 600), timescale: 600)
                                // Start transition time (near end of current photo duration)
                                let transitionStartTime = CMTimeAdd(currentTime, CMTimeSubtract(photoDuration, transitionDuration))
                                
                                // Transition frame count (15 frames = smoother transition)
                                let transitionFrameCount = 15
                                
                                for i in 0..<transitionFrameCount {
                                    // Alpha value (0 to 1)
                                    let progress = CGFloat(i + 1) / CGFloat(transitionFrameCount)
                                    
                                    // Apply transition type
                                    var blendedImage: UIImage?
                                    
                                    switch transitionStyle {
                                    case .none:
                                        // For no transition, we'll just show a hard cut
                                        blendedImage = i < transitionFrameCount / 2 ? resizedImage : nextImage
                                    case .crossFade:
                                        // Blend the two images
                                        blendedImage = resizedImage.blend(with: nextImage, alpha: progress)
                                    case .slide:
                                        // Slide transition
                                        blendedImage = createSlideTransition(from: resizedImage, to: nextImage, progress: progress)
                                    case .zoom:
                                        // Zoom transition
                                        blendedImage = createZoomTransition(from: resizedImage, to: nextImage, progress: progress)
                                    case .wipeRight:
                                        // Wipe Right transition
                                        blendedImage = createWipeTransition(from: resizedImage, to: nextImage, progress: progress, direction: .right)
                                    case .wipeLeft:
                                        // Wipe Left transition
                                        blendedImage = createWipeTransition(from: resizedImage, to: nextImage, progress: progress, direction: .left)
                                    case .wipeUp:
                                        // Wipe Up transition
                                        blendedImage = createWipeTransition(from: resizedImage, to: nextImage, progress: progress, direction: .up)
                                    case .wipeDown:
                                        // Wipe Down transition
                                        blendedImage = createWipeTransition(from: resizedImage, to: nextImage, progress: progress, direction: .down)
                                    case .dissolve:
                                        // Dissolve transition
                                        blendedImage = createDissolveTransition(from: resizedImage, to: nextImage, progress: progress)
                                    case .pageCurl:
                                        // Page Curl transition
                                        blendedImage = createPageCurlTransition(from: resizedImage, to: nextImage, progress: progress)
                                    case .ripple:
                                        // Ripple transition
                                        blendedImage = createRippleTransition(from: resizedImage, to: nextImage, progress: progress)
                                    }
                                    
                                    if let blendImage = blendedImage, let transitionBuffer = createPixelBuffer(from: blendImage) {
                                        // Calculate exact time for transition frame
                                        let frameTime = CMTimeAdd(
                                            transitionStartTime,
                                            CMTime(
                                                value: Int64(i) * Int64(transitionDuration.value) / Int64(transitionFrameCount),
                                                timescale: transitionDuration.timescale
                                            )
                                        )
                                        
                                        // Add frame to video
                                        adaptor.append(transitionBuffer, withPresentationTime: frameTime)
                                    }
                                }
                            }
                            // Son fotoğraf için görüntülenme süresinin tam uygulanması gerekir
                            else if index == images.count - 1 {
                                // Son fotoğraf için ikinci bir frame ekle, böylece son fotoğraf belirtilen süre kadar görünür
                                let endTime = CMTimeAdd(currentTime, photoDuration)
                                
                                // Videoyu son fotoğrafın tam süresi kadar uzat
                                // (önceki resim 0 anında eklendi, şimdi son anı ekliyoruz)
                                if let finalBuffer = createPixelBuffer(from: resizedImage) {
                                    // En son fotoğrafın duration'ının sonundaki frameTime'ı ekle
                                    adaptor.append(finalBuffer, withPresentationTime: CMTimeSubtract(endTime, CMTime(value: 1, timescale: 600)))
                                }
                            }
                            
                            // Update timestamp for next photo
                            currentTime = CMTimeAdd(currentTime, photoDuration)
                        }
                        
                        frameGroup.leave()
                    }
                    
                    frameGroup.wait()
                    
                    // Finalize writing after all frames are processed
                    writerInput.markAsFinished()
                    
                    // Wait for completion
                    let finishGroup = DispatchGroup()
                    finishGroup.enter()
                    
                    assetWriter.finishWriting {
                        finishGroup.leave()
                    }
                    
                    finishGroup.wait()
                    
                    // Send result to main thread
                    DispatchQueue.main.async {
                        if let writerError = error ?? assetWriter.error {
                            print("Video creation failed: \(writerError.localizedDescription)")
                            completion(nil, writerError)
                        } else if assetWriter.status == .completed {
                            print("Video created successfully at: \(outputURL.path)")
                            completion(outputURL, nil)
                        } else {
                            let statusError = NSError(domain: "WTransform", code: 8, userInfo: [NSLocalizedDescriptionKey: "Writer finished with unexpected status: \(assetWriter.status.rawValue)"])
                            completion(nil, statusError)
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    print("Video creation error: \(error.localizedDescription)")
                    completion(nil, error)
                }
            }
        }
    }
    
    func saveVideoToLibrary(url: URL, completion: @escaping (Bool, Error?) -> Void) {
        // Check photo library permissions
        if PHPhotoLibrary.authorizationStatus() != .authorized {
            PHPhotoLibrary.requestAuthorization { status in
                if status == .authorized {
                    self.performVideoSave(url: url, completion: completion)
                } else {
                    let error = NSError(domain: "WTransform", code: 403, userInfo: [NSLocalizedDescriptionKey: "Photo library access permission denied"])
                    DispatchQueue.main.async {
                        completion(false, error)
                    }
                }
            }
        } else {
            performVideoSave(url: url, completion: completion)
        }
    }
    
    private func performVideoSave(url: URL, completion: @escaping (Bool, Error?) -> Void) {
        // Check if video file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            let error = NSError(domain: "WTransform", code: 404, userInfo: [NSLocalizedDescriptionKey: "Video file not found"])
            DispatchQueue.main.async {
                completion(false, error)
            }
            return
        }
        
        // Save to photo library with improved error handling
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .video, fileURL: url, options: nil)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("Video successfully saved to gallery: \(url.lastPathComponent)")
                } else if let error = error {
                    print("Error saving video: \(error.localizedDescription)")
                }
                completion(success, error)
            }
        }
    }
    
    func deletePhoto(_ photo: CapturedImage) {
        let fileManager = FileManager.default
        
        do {
            // Remove the file
            try fileManager.removeItem(at: photo.url)
            
            // Update the array
            DispatchQueue.main.async {
                self.capturedImages.removeAll { $0.id == photo.id }
            }
        } catch {
            print("Error deleting photo: \(error)")
        }
    }
}
