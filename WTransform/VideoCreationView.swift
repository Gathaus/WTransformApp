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
    @State private var videoTitle = ""
    @State private var enableTransition = true
    @State private var transitionStyle: TransitionStyle = .crossFade
    @State private var includeDate = true
    @State private var videoSpeed: VideoSpeed = .normal
    
    enum DateRangeOption: String, CaseIterable, Identifiable {
        case lastWeek = "Son Hafta"
        case lastMonth = "Son Ay"
        case last3Months = "Son 3 Ay"
        case last6Months = "Son 6 Ay"
        case lastYear = "Son Yıl"
        case custom = "Özel Tarih Aralığı"
        case allTime = "Tüm Zamanlar"
        
        var id: String { self.rawValue }
    }
    
    enum TransitionStyle: String, CaseIterable, Identifiable {
        case crossFade = "Geçiş Efekti"
        case slide = "Kaydırma Efekti"
        case zoom = "Zoom Efekti"
        case none = "Efekt Yok"
        
        var id: String { self.rawValue }
    }
    
    enum VideoSpeed: String, CaseIterable, Identifiable {
        case slow = "Yavaş"
        case normal = "Normal"
        case fast = "Hızlı"
        case veryFast = "Çok Hızlı"
        
        var id: String { self.rawValue }
        
        var durationMultiplier: Double {
            switch self {
            case .slow: return 2.0
            case .normal: return 1.0
            case .fast: return 0.5
            case .veryFast: return 0.25
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
            .navigationTitle("Dönüşüm Videosu")
            .alert(isPresented: $showingError) {
                Alert(
                    title: Text("Hata"),
                    message: Text(errorMessage ?? "Bilinmeyen bir hata oluştu"),
                    dismissButton: .default(Text("Tamam"))
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
            
            Text("Video oluşturmak için fotoğraf gerekli")
                .font(.title2)
                .foregroundColor(.gray)
            
            Text("Dönüşümünüzü görmek için önce fotoğraf çekmelisiniz")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                // Switch to camera tab
            }) {
                Label("Fotoğraf Çek", systemImage: "camera")
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
            
            Text("Kişisel Dönüşüm Videonu Oluştur")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Fotoğraflarınızdan etkileyici bir zaman akışı videosu oluşturun")
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
                Text("Tarih Aralığı")
                    .font(.headline)
                Spacer()
            }
            
            Picker("Tarih Aralığı", selection: $selectedDateRange) {
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
                        Text("Tarih Aralığı Seç")
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
                Text("\(filteredPhotos.count) fotoğraf seçildi")
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
                Text("Seçilen Fotoğraflar")
                    .font(.headline)
                Spacer()
            }
            
            if filteredPhotos.isEmpty {
                Text("Bu tarih aralığında fotoğraf bulunamadı")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(filteredPhotos.prefix(15)) { photo in
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
                                        .stroke(Color.white, lineWidth: 2)
                                )
                                
                                Text(formatShortDate(photo.date))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if filteredPhotos.count > 15 {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 100, height: 150)
                                
                                VStack {
                                    Text("+\(filteredPhotos.count - 15)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    
                                    Text("Daha Fazla\nFotoğraf")
                                        .font(.caption)
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.white)
                                }
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
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "gear")
                    .foregroundColor(.blue)
                Text("Video Ayarları")
                    .font(.headline)
                Spacer()
            }
            
            TextField("Video Başlığı (Opsiyonel)", text: $videoTitle)
                .padding(12)
                .background(Color(.systemGroupedBackground))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Geçiş Efekti")
                    .font(.subheadline)
                
                HStack {
                    Toggle("", isOn: $enableTransition)
                        .labelsHidden()
                    
                    if enableTransition {
                        Picker("Geçiş Stili", selection: $transitionStyle) {
                            ForEach(TransitionStyle.allCases) { style in
                                Text(style.rawValue).tag(style)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: .infinity)
                    } else {
                        Text("Devre Dışı")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(8)
                .background(Color(.systemGroupedBackground))
                .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Video Hızı")
                    .font(.subheadline)
                
                Picker("Video Hızı", selection: $videoSpeed) {
                    ForEach(VideoSpeed.allCases) { speed in
                        Text(speed.rawValue).tag(speed)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            HStack {
                Toggle("Tarih Etiketi Göster", isOn: $includeDate)
                    .font(.subheadline)
            }
            .padding(8)
            .background(Color(.systemGroupedBackground))
            .cornerRadius(8)
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
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Video İşleniyor...")
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
                        Text("Dönüşüm Videosu Oluştur")
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
            .disabled(isCreatingVideo || filteredPhotos.isEmpty)
            .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 3)
            
            // Show video button if available
            if let _ = generatedVideoURL, !isCreatingVideo {
                Button(action: {
                    showingVideo = true
                }) {
                    HStack(spacing: 15) {
                        Image(systemName: "play.circle.fill")
                            .font(.title3)
                        Text("Videoyu Oynat")
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
                        Text("Galeriye Kaydet")
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
                    Section(header: Text("Başlangıç Tarihi")) {
                        DatePicker("", selection: $startDate, displayedComponents: .date)
                            .datePickerStyle(GraphicalDatePickerStyle())
                            .labelsHidden()
                    }
                    
                    Section(header: Text("Bitiş Tarihi")) {
                        DatePicker("", selection: $endDate, displayedComponents: .date)
                            .datePickerStyle(GraphicalDatePickerStyle())
                            .labelsHidden()
                    }
                }
            }
            .navigationTitle("Tarih Aralığı Seçin")
            .navigationBarItems(
                leading: Button("İptal") {
                    showingDatePicker = false
                },
                trailing: Button("Uygula") {
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
        guard !filteredPhotos.isEmpty else {
            errorMessage = "Video oluşturmak için fotoğraf bulunamadı"
            showingError = true
            return
        }
        
        isCreatingVideo = true
        
        // Here you would update the createVideo method to pass the new parameters
        // For demonstration, we'll simply call the existing method
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
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }
    
    func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yy"
        return formatter.string(from: date)
    }
}
