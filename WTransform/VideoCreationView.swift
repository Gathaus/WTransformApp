//
//  VideoCreationView.swift
//  WTransform
//
//  Created by Claude on 9.03.2025.
//

import SwiftUI
import AVKit

struct VideoCreationView: View {
    @ObservedObject var photoManager: PhotoService
    @ObservedObject var subscriptionService: SubscriptionService
    @State private var isCreatingVideo = false
    @State private var processingProgress = 0.0
    @State private var generatedVideoURL: URL?
    @State private var showingVideo = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var selectedDateRange: DateRangeOption = .allTime
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var showingDatePicker = false
    @State private var videoTitle = ""
    @State private var enableTransition = true
    @State private var transitionStyle: TransitionStyle = .crossFade
    @State private var includeDate = true
    @State private var videoSpeed: VideoSpeed = .normal
    @State private var selectedPhotos: Set<String> = Set()
    @State private var useSelectedPhotosOnly = false
    @State private var isShowingLoadingAnimation = false
    @State private var enableBackgroundMusic = false
    @State private var selectedMusic: String = "None"
    @State private var musicVolume: Double = 0.5
    
    let availableMusicTracks = ["Uplifting", "Motivational", "Relaxing", "Energetic", "Emotional"]
    
    enum DateRangeOption: String, CaseIterable, Identifiable {
        case lastWeek = "Last Week"
        case lastMonth = "Last Month"
        case last3Months = "Last 3 Months"
        case last6Months = "Last 6 Months"
        case lastYear = "Last Year"
        case custom = "Custom Date Range"
        case allTime = "All Time"
        
        var id: String { self.rawValue }
    }
    
    enum VideoSpeed: String, CaseIterable, Identifiable {
        case veryFast = "Very Fast"
        case fast = "Fast"
        case normal = "Normal"
        case slow = "Slow"
        
        var id: String { self.rawValue }
        
        var photoDuration: Double {
            switch self {
            case .veryFast: return 0.5
            case .fast: return 1.5
            case .normal: return 3.5
            case .slow: return 8.0
            }
        }
    }
    
    var filteredPhotos: [CapturedImage] {
        let photos = photoManager.capturedImages
        
        switch selectedDateRange {
        case .lastWeek:
            let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            return photos.filter { $0.date >= oneWeekAgo }
        case .lastMonth:
            let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
            return photos.filter { $0.date >= oneMonthAgo }
        case .last3Months:
            let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
            return photos.filter { $0.date >= threeMonthsAgo }
        case .last6Months:
            let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
            return photos.filter { $0.date >= sixMonthsAgo }
        case .lastYear:
            let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
            return photos.filter { $0.date >= oneYearAgo }
        case .custom:
            return photos.filter { $0.date >= startDate && $0.date <= endDate }
        case .allTime:
            return photos
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .edgesIgnoringSafeArea(.all)
                
                if photoManager.capturedImages.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            headerView
                            
                            dateRangeSection
                            
                            photoPreviewSection
                            
                            videoOptionsSection
                            
                            createVideoButtonSection
                        }
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("Transformation Video")
            .alert(isPresented: $showingError) {
                Alert(
                    title: Text("Error"),
                    message: Text(errorMessage ?? "An unknown error occurred"),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(isPresented: $showingDatePicker) {
                datePickerView
            }
            .fullScreenCover(isPresented: $showingVideo) {
                videoPlayerView
            }
        }
    }
    
    var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.slash")
                .font(.system(size: 80))
                .foregroundColor(.gray)
                .padding(.top, 100)
            
            Text("Photos needed for video creation")
                .font(.title2)
                .foregroundColor(.gray)
            
            Text("You need to take photos first to see your transformation")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                // Switch to camera tab
            }) {
                Label("Take Photo", systemImage: "camera")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top, 20)
        }
    }
    
    var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)
                .padding()
            
            Text("Create Your Transformation Video")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Create an impressive time-lapse video from your photos")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .padding(.horizontal)
        .padding(.top, 10)
    }
    
    var dateRangeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.blue)
                Text("Date Range")
                    .font(.headline)
                Spacer()
            }
            
            Picker("Date Range", selection: $selectedDateRange) {
                ForEach(DateRangeOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding(8)
            .background(Color(.systemBackground))
            .cornerRadius(8)
            
            if selectedDateRange == .custom {
                Button(action: {
                    showingDatePicker = true
                }) {
                    HStack {
                        Text("Select Date Range")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(12)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                }
            }
            
            HStack {
                Text("\(filteredPhotos.count) photos selected")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if !filteredPhotos.isEmpty {
                    Text("\(formatDate(filteredPhotos.first!.date)) - \(formatDate(filteredPhotos.last!.date))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .padding(.horizontal)
    }
    
    var photoPreviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundColor(.blue)
                Text("Selected Photos")
                    .font(.headline)
                Spacer()
                
                Toggle("Selected Photos Only", isOn: $useSelectedPhotosOnly)
                    .font(.caption)
                    .onChange(of: useSelectedPhotosOnly) { oldValue, newValue in
                        if !newValue {
                            selectedPhotos.removeAll()
                        }
                    }
            }
            
            if filteredPhotos.isEmpty {
                Text("No photos found in this date range")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(filteredPhotos) { photo in
                            VStack {
                                AsyncImage(url: photo.url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                }
                                .frame(width: 100, height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedPhotos.contains(photo.id) ? Color.blue : Color.white, lineWidth: 2)
                                )
                                .overlay(
                                    ZStack {
                                        if selectedPhotos.contains(photo.id) {
                                            Circle()
                                                .fill(Color.blue)
                                                .frame(width: 24, height: 24)
                                            
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                    .padding(8)
                                )
                                .onTapGesture {
                                    if useSelectedPhotosOnly {
                                        if selectedPhotos.contains(photo.id) {
                                            selectedPhotos.remove(photo.id)
                                        } else {
                                            selectedPhotos.insert(photo.id)
                                        }
                                    }
                                }
                                
                                Text(formatShortDate(photo.date))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 10)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .padding(.horizontal)
    }
    
    var videoOptionsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Video Options")
                .font(.headline)
                .padding(.top, 8)
                .padding(.horizontal)
            
            // Speed selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Video Speed")
                    .font(.subheadline)
                
                Picker("Video Speed", selection: $videoSpeed) {
                    ForEach(VideoSpeed.allCases) { speed in
                        Text(speed.rawValue).tag(speed)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(8)
                .background(Color(.systemGroupedBackground))
                .cornerRadius(8)
            }
            
            // Transition effect
            VStack(alignment: .leading, spacing: 8) {
                Text("Transition Effect")
                    .font(.subheadline)
                
                HStack {
                    Toggle("", isOn: $enableTransition)
                        .labelsHidden()
                    
                    if enableTransition {
                        Picker("Transition Style", selection: $transitionStyle) {
                            Text("Cross Fade").tag(TransitionStyle.crossFade)
                            
                            if subscriptionService.hasActiveSubscription() || subscriptionService.isTrialActive {
                                Text("Slide").tag(TransitionStyle.slide)
                                Text("Zoom").tag(TransitionStyle.zoom)
                                Text("None").tag(TransitionStyle.none)
                            } else {
                                Text("Slide (Premium)").tag(TransitionStyle.crossFade)
                                    .foregroundColor(.gray)
                                Text("Zoom (Premium)").tag(TransitionStyle.crossFade)
                                    .foregroundColor(.gray)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: .infinity)
                        .onChange(of: transitionStyle) { newValue in
                            // If user is not premium and selects a premium transition,
                            // show an alert and reset to crossFade
                            if !(subscriptionService.hasActiveSubscription() || subscriptionService.isTrialActive) {
                                if newValue == .slide || newValue == .zoom || newValue == .none {
                                    transitionStyle = .crossFade
                                    errorMessage = "Premium transitions are only available with a subscription."
                                    showingError = true
                                }
                            }
                        }
                    } else {
                        Text("Disabled")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(8)
                .background(Color(.systemGroupedBackground))
                .cornerRadius(8)
            }
            
            // Date label toggle
            HStack {
                if subscriptionService.hasActiveSubscription() || subscriptionService.isTrialActive {
                    Toggle("Show Date Label", isOn: $includeDate)
                        .font(.subheadline)
                } else {
                    Text("Date Label (Premium to remove)")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
            }
            .padding(8)
            .background(Color(.systemGroupedBackground))
            .cornerRadius(8)
            
            // Background music (Premium only)
            if subscriptionService.hasActiveSubscription() || subscriptionService.isTrialActive {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Background Music")
                        .font(.subheadline)
                    
                    HStack {
                        Toggle("", isOn: $enableBackgroundMusic)
                            .labelsHidden()
                        
                        if enableBackgroundMusic {
                            Picker("Music Track", selection: $selectedMusic) {
                                Text("None").tag("None")
                                ForEach(availableMusicTracks, id: \.self) { track in
                                    Text(track).tag(track)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(maxWidth: .infinity)
                        } else {
                            Text("No music")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(8)
                    .background(Color(.systemGroupedBackground))
                    .cornerRadius(8)
                    
                    if enableBackgroundMusic && selectedMusic != "None" {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Music Volume: \(Int(musicVolume * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Slider(value: $musicVolume, in: 0...1, step: 0.05)
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                        .background(Color(.systemGroupedBackground))
                        .cornerRadius(8)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "music.note")
                            .foregroundColor(.secondary)
                        Text("Background Music (Premium)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Image(systemName: "lock.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding(8)
                    .background(Color(.systemGroupedBackground))
                    .cornerRadius(8)
                    .onTapGesture {
                        errorMessage = "Background music is a premium feature. Please subscribe to use it."
                        showingError = true
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .padding(.horizontal)
    }
    
    var createVideoButtonSection: some View {
        VStack(spacing: 16) {
            // Create video button with gradient
            Button(action: createVideo) {
                if isCreatingVideo {
                    HStack(spacing: 15) {
                        if isShowingLoadingAnimation {
                            LoadingAnimationView()
                                .frame(width: 30, height: 30)
                        } else {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text("Processing Video...")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 55)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.blue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(15)
                } else {
                    HStack(spacing: 15) {
                        Image(systemName: "sparkles.square.filled.on.square")
                            .font(.title3)
                        Text("Create Transformation Video")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 55)
                    .foregroundColor(.white)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(15)
                }
            }
            .disabled(isCreatingVideo || (useSelectedPhotosOnly && selectedPhotos.isEmpty) || (!useSelectedPhotosOnly && filteredPhotos.isEmpty))
            .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 3)
            
            // Show video button if available
            if let _ = generatedVideoURL, !isCreatingVideo {
                Button(action: {
                    showingVideo = true
                }) {
                    HStack(spacing: 15) {
                        Image(systemName: "play.circle.fill")
                            .font(.title3)
                        Text("Play Video")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 55)
                    .foregroundColor(.white)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.green, Color.green.opacity(0.7)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(15)
                }
                .shadow(color: Color.green.opacity(0.3), radius: 5, x: 0, y: 3)
            }
            
            // Save video button if available
            if let videoURL = generatedVideoURL, !isCreatingVideo {
                Button(action: {
                    saveVideoToGallery(url: videoURL)
                }) {
                    HStack(spacing: 15) {
                        Image(systemName: "square.and.arrow.down.fill")
                            .font(.title3)
                        Text("Save to Gallery")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 55)
                    .foregroundColor(.white)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.purple, Color.purple.opacity(0.7)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(15)
                }
                .shadow(color: Color.purple.opacity(0.3), radius: 5, x: 0, y: 3)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .padding(.horizontal)
    }
    
    var datePickerView: some View {
        NavigationView {
            VStack {
                Form {
                    Section(header: Text("Start Date")) {
                        DatePicker("", selection: $startDate, displayedComponents: .date)
                            .datePickerStyle(GraphicalDatePickerStyle())
                            .labelsHidden()
                    }
                    
                    Section(header: Text("End Date")) {
                        DatePicker("", selection: $endDate, displayedComponents: .date)
                            .datePickerStyle(GraphicalDatePickerStyle())
                            .labelsHidden()
                    }
                }
            }
            .navigationTitle("Select Date Range")
            .navigationBarItems(
                leading: Button("Cancel") {
                    showingDatePicker = false
                },
                trailing: Button("Apply") {
                    showingDatePicker = false
                }
                .fontWeight(.bold)
            )
        }
    }
    
    var videoPlayerView: some View {
        ZStack {
            if let videoURL = generatedVideoURL {
                VideoPlayer(player: AVPlayer(url: videoURL))
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            showingVideo = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .padding()
                    }
                    Spacer()
                }
            }
        }
        .background(Color.black)
    }
    
    func createVideo() {
        // Set loading state immediately to prevent UI freeze
        isCreatingVideo = true
        isShowingLoadingAnimation = true
        
        // Use a small delay to let the UI update before starting heavy processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Determine which photos to use
            var photosToUse: [CapturedImage]
            
            if self.useSelectedPhotosOnly && !self.selectedPhotos.isEmpty {
                photosToUse = self.filteredPhotos.filter { self.selectedPhotos.contains($0.id) }
            } else {
                photosToUse = self.filteredPhotos
            }
            
            guard !photosToUse.isEmpty else {
                self.isCreatingVideo = false
                self.isShowingLoadingAnimation = false
                self.errorMessage = "No photos found to create video"
                self.showingError = true
                return
            }
            
            // Transition style'ı belirle
            let style: TransitionStyle = self.enableTransition ? self.transitionStyle : .none
            
            // Pass the duration from videoSpeed and transition style
            self.photoManager.createVideo(
                from: photosToUse, 
                duration: self.videoSpeed.photoDuration,
                transitionStyle: style
            ) { url, error in
                DispatchQueue.main.async {
                    self.isCreatingVideo = false
                    self.isShowingLoadingAnimation = false
                    
                    if let error = error {
                        self.errorMessage = "Error creating video: \(error.localizedDescription)"
                        self.showingError = true
                        return
                    }
                    
                    if let url = url {
                        self.generatedVideoURL = url
                        self.showingVideo = true
                    }
                }
            }
        }
    }
    
    func saveVideoToGallery(url: URL) {
        if subscriptionService.hasActiveSubscription() || subscriptionService.isTrialActive {
            // Premium user - save directly without watermark
            photoManager.saveVideoToLibrary(url: url) { success, error in
                DispatchQueue.main.async {
                    if success {
                        // Show success message
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    } else if let error = error {
                        errorMessage = "Error saving video: \(error.localizedDescription)"
                        showingError = true
                    }
                }
            }
        } else {
            // Non-premium user - apply watermark before saving
            let watermarkedURL = applyWatermark(to: url)
            
            // Save the watermarked video
            photoManager.saveVideoToLibrary(url: watermarkedURL) { success, error in
                DispatchQueue.main.async {
                    if success {
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    } else if let error = error {
                        self.errorMessage = "Error saving video: \(error.localizedDescription)"
                        self.showingError = true
                    }
                }
            }
        }
    }
    
    // Helper function to apply watermark to video
    func applyWatermark(to videoURL: URL) -> URL {
        // In a real implementation, this would use AVFoundation to apply a watermark
        // For now, we'll just return the original URL since we can't implement the actual watermarking without more code
        // This is a placeholder for the watermarking functionality
        return videoURL
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }
    
    func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
    
    func getSpeedDescription() -> String {
        switch videoSpeed {
        case .veryFast:
            return "0.5 seconds per photo (Fastest)"
        case .fast:
            return "1.5 seconds per photo (Fast pace)"
        case .normal:
            return "3.5 seconds per photo (Normal speed)"
        case .slow:
            return "8 seconds per photo (Slow viewing)"
        }
    }
}

struct LoadingAnimationView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 3)
                .opacity(0.3)
                .foregroundColor(.white)
            
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(lineWidth: 3)
                .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                .animation(Animation.linear(duration: 0.8).repeatForever(autoreverses: false), value: isAnimating)
                .foregroundColor(.white)
        }
        .onAppear {
            self.isAnimating = true
        }
    }
}
