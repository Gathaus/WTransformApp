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
            VStack {
                if photoManager.capturedImages.isEmpty {
                    emptyStateView
                } else {
                    videoCreationContent
                }
            }
            .navigationTitle("Create Video")
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
            
            Text("Photos are required to create a video")
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
    
    var videoCreationContent: some View {
        VStack(spacing: 20) {
            // Date range selector
            VStack(alignment: .leading) {
                Text("Select Date Range")
                    .font(.headline)
                    .padding(.horizontal)
                
                Picker("Date Range", selection: $selectedDateRange) {
                    ForEach(DateRangeOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding(.horizontal)
                
                if selectedDateRange == .custom {
                    Button("Select Date Range") {
                        showingDatePicker = true
                    }
                    .padding(.horizontal)
                }
                
                Text("\(filteredPhotos.count) photos selected")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            .padding(.vertical)
            .background(Color(.systemGroupedBackground))
            .cornerRadius(10)
            .padding(.horizontal)
            
            // Preview of selected photos
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(filteredPhotos.prefix(10)) { photo in
                        AsyncImage(url: photo.url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.gray
                        }
                        .frame(width: 80, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white, lineWidth: 2)
                        )
                    }
                    
                    if filteredPhotos.count > 10 {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 80, height: 120)
                            
                            Text("+\(filteredPhotos.count - 10)")
                                .font(.title2)
                                .foregroundColor(.white)
                                .fontWeight(.bold)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
            
            // Create video button
            Button(action: createVideo) {
                if isCreatingVideo {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Processing...")
                            .foregroundColor(.white)
                    }
                    .frame(width: 250, height: 50)
                    .background(Color.blue)
                    .cornerRadius(10)
                } else {
                    Text("Dönüşüm Videosu Oluştur")
                        .foregroundColor(.white)
                        .frame(width: 250, height: 50)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
            }
            .disabled(isCreatingVideo || filteredPhotos.isEmpty)
            
            // Show video button if available
            if let _ = generatedVideoURL, !isCreatingVideo {
                Button(action: {
                    showingVideo = true
                }) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                        Text("Videoyu Göster")
                    }
                    .foregroundColor(.white)
                    .frame(width: 250, height: 50)
                    .background(Color.green)
                    .cornerRadius(10)
                }
            }
            
            // Save video button if available
            if let videoURL = generatedVideoURL, !isCreatingVideo {
                Button(action: {
                    saveVideoToGallery(url: videoURL)
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down.fill")
                        Text("Videoyu Kaydet")
                    }
                    .foregroundColor(.white)
                    .frame(width: 250, height: 50)
                    .background(Color.purple)
                    .cornerRadius(10)
                }
            }
            
            Spacer()
        }
    }
    
    var datePickerView: some View {
        NavigationView {
            VStack {
                Form {
                    DatePicker("Başlangıç Tarihi", selection: $startDate, displayedComponents: .date)
                    DatePicker("Bitiş Tarihi", selection: $endDate, displayedComponents: .date)
                }
            }
            .navigationTitle("Tarih Aralığı Seçin")
            .navigationBarItems(
                leading: Button("İptal") {
                    showingDatePicker = false
                },
                trailing: Button("Tamam") {
                    showingDatePicker = false
                }
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
                        }
                    }
                    Spacer()
                }
            }
        }
        .background(Color.black)
    }
    
    func createVideo() {
        guard !filteredPhotos.isEmpty else {
            errorMessage = "Video oluşturmak için fotoğraf bulunamadı"
            showingError = true
            return
        }
        
        isCreatingVideo = true
        
        photoManager.createVideo(from: filteredPhotos) { url, error in
            DispatchQueue.main.async {
                isCreatingVideo = false
                
                if let error = error {
                    errorMessage = "Video oluşturulurken hata: \(error.localizedDescription)"
                    showingError = true
                    return
                }
                
                if let url = url {
                    generatedVideoURL = url
                    showingVideo = true
                }
            }
        }
    }
    
    func saveVideoToGallery(url: URL) {
        photoManager.saveVideoToLibrary(url: url) { success, error in
            DispatchQueue.main.async {
                if success {
                    // Show success message
                } else if let error = error {
                    errorMessage = "Video kaydedilirken hata: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
}
