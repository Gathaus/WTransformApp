import SwiftUI
import Foundation

struct PhotoGalleryView: View {
    @ObservedObject var photoManager: PhotoService
    @ObservedObject var subscriptionService: SubscriptionService
    @State private var showingActionSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var selectedPhoto: CapturedImage?
    @State private var showingImageViewer = false
    @State private var showingVideoCreation = false
    @State private var showingSubscriptionView = false
    @State private var showingWatermarkSettings = false
    @State private var showingFilterOptions = false
    @State private var searchText = ""
    @State private var isEditMode = false
    @State private var selectedPhotos = Set<String>()
    @State private var isMultiSelectEnabled = false
    @State private var showingFeatureLockedAlert = false
    @State private var lockedFeatureMessage = ""
    
    // MARK: - Computed Properties
    
    var filteredPhotos: [CapturedImage] {
        if searchText.isEmpty {
            return photoManager.capturedImages
        } else {
            return photoManager.capturedImages.filter { photo in
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "dd MMMM yyyy"
                let dateString = dateFormatter.string(from: photo.date)
                return dateString.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var isAnyPhotoSelected: Bool {
        return !selectedPhotos.isEmpty
    }
    
    var isPremiumUser: Bool {
        return subscriptionService.currentTier != .free || subscriptionService.isTrialActive
    }
    
    // MARK: - View Body
    
    var body: some View {
        NavigationView {
            ZStack {
                if photoManager.capturedImages.isEmpty {
                    emptyStateView
                } else {
                    VStack(spacing: 0) {
                        if isMultiSelectEnabled {
                            multiSelectToolbar
                        }
                        
                        SearchBar(text: $searchText, placeholder: "Search by date")
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        
                        ScrollView {
                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: 3),
                                    GridItem(.flexible(), spacing: 3),
                                    GridItem(.flexible(), spacing: 3)
                                ],
                                spacing: 3
                            ) {
                                ForEach(filteredPhotos) { photo in
                                    PhotoGridItem(
                                        photo: photo,
                                        isSelected: selectedPhotos.contains(photo.id),
                                        isMultiSelectEnabled: isMultiSelectEnabled,
                                        onTap: {
                                            if isMultiSelectEnabled {
                                                togglePhotoSelection(photo)
                                            } else {
                                                selectedPhoto = photo
                                                showingImageViewer = true
                                            }
                                        },
                                        onLongPress: {
                                            if !isMultiSelectEnabled {
                                                isMultiSelectEnabled = true
                                                togglePhotoSelection(photo)
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(3)
                        }
                    }
                }
            }
            .navigationTitle("Transformation Gallery")
            .navigationBarItems(
                leading: leadingBarItems,
                trailing: trailingBarItems
            )
            .sheet(isPresented: $showingImageViewer) {
                if let photo = selectedPhoto {
                    ImageViewer(photo: photo) {
                        selectedPhoto = photo
                        showingActionSheet = true
                    }
                }
            }
            .sheet(isPresented: $showingVideoCreation) {
                VideoCreationView(photoManager: photoManager, subscriptionService: subscriptionService)
            }
            .sheet(isPresented: $showingSubscriptionView) {
                SubscriptionView(subscriptionService: subscriptionService)
            }
            .sheet(isPresented: $showingWatermarkSettings, content: {
                WatermarkSettingsView()
            })
            .sheet(isPresented: $showingFilterOptions, content: {
                FilterOptionsView()
            })
            .actionSheet(isPresented: $showingActionSheet) {
                photoActionSheet()
            }
            .alert(isPresented: $showingDeleteConfirmation) {
                Alert(
                    title: Text("Delete Photo"),
                    message: Text("Are you sure you want to delete this photo? This action cannot be undone."),
                    primaryButton: .destructive(Text("Delete")) {
                        if let photo = selectedPhoto {
                            photoManager.deletePhoto(photo)
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
            .alert(isPresented: $showingFeatureLockedAlert) {
                Alert(
                    title: Text("Premium Feature"),
                    message: Text(lockedFeatureMessage),
                    primaryButton: .default(Text("Upgrade")) {
                        showingSubscriptionView = true
                    },
                    secondaryButton: .cancel()
                )
            }
            .onAppear {
                photoManager.loadSavedImages()
                setupNotifications()
            }
            .onDisappear {
                cleanupNotifications()
            }
        }
    }
    
    // MARK: - UI Components
    
    var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 70))
                .foregroundColor(.gray)
                .padding(.bottom, 10)
            
            Text("No Photos Yet")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Start capturing photos to track your transformation")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            
            Button(action: {
                // Navigate to camera tab
            }) {
                Text("Take Your First Photo")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.top, 20)
        }
        .padding()
    }
    
    var leadingBarItems: some View {
        Group {
            if isMultiSelectEnabled {
                Button(action: {
                    isMultiSelectEnabled = false
                    selectedPhotos.removeAll()
                }) {
                    Text("Cancel")
                }
            } else {
                EmptyView()
            }
        }
    }
    
    var trailingBarItems: some View {
        Group {
            if isMultiSelectEnabled {
                Menu {
                    if isAnyPhotoSelected {
                        Button(action: {
                            // Handle delete selected
                            for id in selectedPhotos {
                                if let photo = photoManager.capturedImages.first(where: { $0.id == id }) {
                                    photoManager.deletePhoto(photo)
                                }
                            }
                            selectedPhotos.removeAll()
                            isMultiSelectEnabled = false
                        }) {
                            Label("Delete Selected", systemImage: "trash")
                        }
                        
                        Button(action: {
                            checkAndShowVideoCreation()
                        }) {
                            Label("Create Video", systemImage: "video")
                        }
                        
                        if isPremiumUser {
                            Button(action: {
                                showingWatermarkSettings = true
                            }) {
                                Label("Add Watermark", systemImage: "signature")
                            }
                            
                            Button(action: {
                                showingFilterOptions = true
                            }) {
                                Label("Apply Filters", systemImage: "wand.and.stars")
                            }
                        } else {
                            Button(action: {
                                showPremiumFeatureAlert(message: "Add your own custom watermark to protect your transformation videos with a Premium subscription.")
                            }) {
                                Label("Add Watermark", systemImage: "signature")
                            }
                            
                            Button(action: {
                                showPremiumFeatureAlert(message: "Enhance your photos with professional filters and effects with a Premium subscription.")
                            }) {
                                Label("Apply Filters", systemImage: "wand.and.stars")
                            }
                        }
                    }
                    
                    Button(action: {
                        selectedPhotos = Set(photoManager.capturedImages.map { $0.id })
                    }) {
                        Label("Select All", systemImage: "checkmark.circle")
                    }
                    
                    Button(action: {
                        selectedPhotos.removeAll()
                    }) {
                        Label("Deselect All", systemImage: "circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            } else {
                Button(action: {
                    isMultiSelectEnabled = true
                }) {
                    Image(systemName: "checkmark.circle")
                }
            }
        }
    }
    
    var multiSelectToolbar: some View {
        HStack {
            Text("\(selectedPhotos.count) selected")
                .foregroundColor(.primary)
                .padding(.leading, 15)
            
            Spacer()
            
            Button(action: {
                checkAndShowVideoCreation()
            }) {
                Image(systemName: "video")
                    .padding(8)
                    .background(isAnyPhotoSelected ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .clipShape(Circle())
            }
            .disabled(!isAnyPhotoSelected)
            
            Button(action: {
                // Handle delete selected
                for id in selectedPhotos {
                    if let photo = photoManager.capturedImages.first(where: { $0.id == id }) {
                        photoManager.deletePhoto(photo)
                    }
                }
                selectedPhotos.removeAll()
                isMultiSelectEnabled = false
            }) {
                Image(systemName: "trash")
                    .padding(8)
                    .background(isAnyPhotoSelected ? Color.red : Color.gray)
                    .foregroundColor(.white)
                    .clipShape(Circle())
            }
            .disabled(!isAnyPhotoSelected)
            .padding(.trailing, 15)
        }
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - Action Methods
    
    func togglePhotoSelection(_ photo: CapturedImage) {
        if selectedPhotos.contains(photo.id) {
            selectedPhotos.remove(photo.id)
        } else {
            selectedPhotos.insert(photo.id)
        }
    }
    
    func photoActionSheet() -> ActionSheet {
        var buttons: [ActionSheet.Button] = [
            .default(Text("View Full Screen")) {
                showingImageViewer = true
            },
            .destructive(Text("Delete Photo")) {
                showingDeleteConfirmation = true
            },
            .cancel()
        ]
        
        if isPremiumUser {
            buttons.insert(.default(Text("Edit Photo")) {
                if isPremiumUser {
                    // Open photo editor
                } else {
                    showPremiumFeatureAlert(message: "Access advanced photo editing tools with a Premium subscription.")
                }
            }, at: 1)
        }
        
        return ActionSheet(
            title: Text("Photo Options"),
            message: Text("Choose an action"),
            buttons: buttons
        )
    }
    
    func checkAndShowVideoCreation() {
        // If user can create more videos, proceed; otherwise show upgrade alert
        if subscriptionService.canCreateMoreVideos() {
            showingVideoCreation = true
            subscriptionService.incrementVideosCreated() // Count it only when they actually create a video
        } else {
            showPremiumFeatureAlert(message: "You've reached the limit of free videos. Upgrade to create unlimited videos.")
        }
    }
    
    func showPremiumFeatureAlert(message: String) {
        lockedFeatureMessage = message
        showingFeatureLockedAlert = true
    }
    
    // Notification işleyicilerini kurma
    private func setupNotifications() {
        // Delete photo notification'ı dinle
        NotificationCenter.default.addObserver(
            forName: Notification.Name("DeletePhoto"),
            object: nil,
            queue: .main
        ) { notification in
            if let photo = notification.object as? CapturedImage {
                // Silme onayı için seçili fotoğrafı ayarla
                selectedPhoto = photo
                showingDeleteConfirmation = true
            }
        }
    }
    
    // Notification dinleyicilerini temizleme
    private func cleanupNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Supporting Views

struct PhotoGridItem: View {
    let photo: CapturedImage
    let isSelected: Bool
    let isMultiSelectEnabled: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    @State private var showDeleteButton = false
    
    var body: some View {
        ZStack {
            AsyncImage(url: photo.url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .background(Color.gray.opacity(0.2))
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .clipped()
                        .overlay(
                            ZStack {
                                if isMultiSelectEnabled {
                                    Rectangle()
                                        .fill(isSelected ? Color.blue.opacity(0.4) : Color.black.opacity(0.15))
                                    
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 28))
                                        .foregroundColor(isSelected ? .blue : .white)
                                        .background(
                                            Circle()
                                                .fill(isSelected ? Color.white : Color.black.opacity(0.3))
                                                .frame(width: 32, height: 32)
                                        )
                                        .padding(6)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                }
                                
                                // Tarih bilgisi
                                VStack {
                                    Spacer()
                                    Text(formatDate(photo.date))
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(4)
                                        .background(Color.black.opacity(0.6))
                                        .cornerRadius(4)
                                        .padding(4)
                                }
                                
                                // Silme düğmesi
                                if showDeleteButton && !isMultiSelectEnabled {
                                    VStack {
                                        HStack {
                                            Spacer()
                                            Button(action: {
                                                // Fotoğrafı silme işlemi
                                                deletePhoto(photo)
                                            }) {
                                                Image(systemName: "trash.circle.fill")
                                                    .font(.system(size: 22))
                                                    .foregroundColor(.red)
                                                    .background(Circle().fill(Color.white))
                                            }
                                            .padding(6)
                                        }
                                        Spacer()
                                    }
                                }
                            }
                        )
                case .failure(_):
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .background(Color.gray.opacity(0.2))
                @unknown default:
                    EmptyView()
                }
            }
        }
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture {
            onLongPress()
        }
        .onHover { hovering in
            withAnimation {
                showDeleteButton = hovering
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }
    
    private func deletePhoto(_ photo: CapturedImage) {
        // PhotoManager örneğine erişimimiz yok, notification ile işlem yapmamız gerekebilir
        // Geçici çözüm: Ana sınıftan bir deletePhoto fonksiyonu çağırmak
        NotificationCenter.default.post(name: Notification.Name("DeletePhoto"), object: photo)
    }
}

struct ImageViewer: View {
    let photo: CapturedImage
    let onActionTap: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showControls = true
    @Environment(\.presentationMode) private var presentationMode
    
    // Görüntünün ne kadar aşağı sürükleneceğini belirlemek için eşik değeri
    private let dismissThreshold: CGFloat = 100
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            AsyncImage(url: photo.url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .foregroundColor(.white)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(dragGesture)
                        .gesture(magnificationGesture)
                        .onTapGesture {
                            withAnimation {
                                showControls.toggle()
                            }
                        }
                case .failure(_):
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                        Text("Failed to load image")
                    }
                    .foregroundColor(.white)
                @unknown default:
                    EmptyView()
                }
            }
            
            if showControls {
                VStack {
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        
                        Spacer()
                        
                        Button(action: onActionTap) {
                            Image(systemName: "ellipsis")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    VStack {
                        Text(formattedDate(photo.date))
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Capsule().fill(Color.black.opacity(0.5)))
                    }
                    .padding(.bottom)
                }
                .transition(.opacity)
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: true)
        .edgesIgnoringSafeArea(.all)
        // Kaydırma sırasında arkaplan rengini transparanlığını ayarla
        .background(
            Color.black.opacity(calculateBackgroundOpacity())
                .edgesIgnoringSafeArea(.all)
        )
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { value in
                // Kullanıcı yeterince aşağı sürüklediyse kapat
                let verticalDrag = value.translation.height
                
                if verticalDrag > dismissThreshold {
                    presentationMode.wrappedValue.dismiss()
                } else {
                    // Küçük sürüklemelerde normale dön
                    withAnimation {
                        // Eğer aşağı doğru az sürükleme yapıldıysa, reset
                        if scale <= 1.0 {
                            offset = .zero
                            lastOffset = .zero
                        } else {
                            lastOffset = offset
                        }
                    }
                }
            }
    }
    
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / lastScale
                lastScale = value
                scale *= delta
            }
            .onEnded { value in
                lastScale = 1.0
                if scale < 1.0 {
                    withAnimation {
                        scale = 1.0
                        offset = .zero
                        lastOffset = .zero
                    }
                }
            }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Sürükleme miktarına göre arkaplan transparanlığını hesapla
    private func calculateBackgroundOpacity() -> Double {
        let maxDragDistance: CGFloat = 300
        let dragPercentage = min(abs(offset.height) / maxDragDistance, 1.0)
        return Double(1.0 - dragPercentage * 0.8) // Min %20 opak
    }
}

struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField(placeholder, text: $text)
                .foregroundColor(.primary)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}

// MARK: - Premium Feature Views

struct WatermarkSettingsView: View {
    @State private var watermarkText = "© My Transformation"
    @State private var watermarkPosition = "Bottom Right"
    @State private var watermarkOpacity = 0.7
    @State private var watermarkSize = 15.0
    @State private var watermarkColor = Color.white
    @Environment(\.presentationMode) private var presentationMode
    
    let positionOptions = ["Top Left", "Top Right", "Bottom Left", "Bottom Right", "Center"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Watermark Text")) {
                    TextField("Enter watermark text", text: $watermarkText)
                }
                
                Section(header: Text("Position")) {
                    Picker("Position", selection: $watermarkPosition) {
                        ForEach(positionOptions, id: \.self) { position in
                            Text(position).tag(position)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Appearance")) {
                    ColorPicker("Color", selection: $watermarkColor)
                    
                    VStack {
                        Text("Opacity: \(Int(watermarkOpacity * 100))%")
                        Slider(value: $watermarkOpacity, in: 0.1...1.0, step: 0.1)
                    }
                    
                    VStack {
                        Text("Size: \(Int(watermarkSize))pt")
                        Slider(value: $watermarkSize, in: 10...30, step: 1)
                    }
                }
                
                Section(header: Text("Preview")) {
                    ZStack {
                        Color.gray.opacity(0.3)
                            .aspectRatio(4/3, contentMode: .fit)
                            .cornerRadius(8)
                        
                        Text(watermarkText)
                            .font(.system(size: watermarkSize))
                            .foregroundColor(watermarkColor)
                            .opacity(watermarkOpacity)
                            .padding()
                            .position(positionForPreview())
                    }
                    .frame(height: 200)
                }
                
                Section {
                    Button(action: {
                        // Apply watermark to selected photos
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Apply Watermark")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
            }
            .navigationTitle("Watermark Settings")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func positionForPreview() -> CGPoint {
        let frame = CGRect(x: 0, y: 0, width: 300, height: 200)
        
        switch watermarkPosition {
        case "Top Left":
            return CGPoint(x: frame.width * 0.2, y: frame.height * 0.2)
        case "Top Right":
            return CGPoint(x: frame.width * 0.8, y: frame.height * 0.2)
        case "Bottom Left":
            return CGPoint(x: frame.width * 0.2, y: frame.height * 0.8)
        case "Bottom Right":
            return CGPoint(x: frame.width * 0.8, y: frame.height * 0.8)
        case "Center":
            return CGPoint(x: frame.width * 0.5, y: frame.height * 0.5)
        default:
            return CGPoint(x: frame.width * 0.5, y: frame.height * 0.5)
        }
    }
}

struct FilterOptionsView: View {
    @State private var selectedFilter = "None"
    @State private var filterIntensity: Double = 0.5
    @State private var brightness: Double = 0.0
    @State private var contrast: Double = 0.0
    @State private var saturation: Double = 0.0
    @Environment(\.presentationMode) private var presentationMode
    
    let filterOptions = ["None", "Mono", "Sepia", "Vibrant", "Noir", "Fade", "Chrome"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Choose Filter")) {
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(filterOptions, id: \.self) { filter in
                            Text(filter).tag(filter)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                if selectedFilter != "None" {
                    Section(header: Text("Filter Intensity")) {
                        VStack {
                            Slider(value: $filterIntensity, in: 0...1)
                            Text("\(Int(filterIntensity * 100))%")
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                }
                
                Section(header: Text("Adjustments")) {
                    HStack {
                        Text("Brightness")
                        Slider(value: $brightness, in: -0.5...0.5, step: 0.1)
                        Text("\(Int(brightness * 100))")
                            .frame(width: 40, alignment: .trailing)
                    }
                    
                    HStack {
                        Text("Contrast")
                        Slider(value: $contrast, in: -0.5...0.5, step: 0.1)
                        Text("\(Int(contrast * 100))")
                            .frame(width: 40, alignment: .trailing)
                    }
                    
                    HStack {
                        Text("Saturation")
                        Slider(value: $saturation, in: -0.5...0.5, step: 0.1)
                        Text("\(Int(saturation * 100))")
                            .frame(width: 40, alignment: .trailing)
                    }
                }
                
                Section(header: Text("Preview")) {
                    // Preview image with filters applied would go here
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 200)
                        .cornerRadius(8)
                        .overlay(
                            Text("Preview")
                                .foregroundColor(.white)
                        )
                }
                
                Section {
                    Button(action: {
                        // Apply filters to selected photos
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Apply to Selected Photos")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
            }
            .navigationTitle("Photo Filters")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
} 