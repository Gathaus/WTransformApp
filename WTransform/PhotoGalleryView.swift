//
//  PhotoGalleryView.swift
//  WTransform
//
//  Created by Claude on 9.03.2025.
//

import SwiftUI

struct PhotoGalleryView: View {
    @ObservedObject var photoManager: PhotoService
    @State private var selectedPhoto: CapturedImage?
    @State private var showingDetailView = false
    
    let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 4)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                if photoManager.capturedImages.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 80))
                            .foregroundColor(.gray)
                            .padding(.top, 100)
                        
                        Text("No photos taken yet")
                            .font(.title2)
                            .foregroundColor(.gray)
                        
                        Text("Take a photo every day to track your transformation")
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
                } else {
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(photoManager.capturedImages) { image in
                            photoItem(image)
                        }
                    }
                    .padding(4)
                }
            }
            .navigationTitle("Transformation Photos")
        }
        .sheet(isPresented: $showingDetailView) {
            if let photo = selectedPhoto {
                PhotoDetailView(photo: photo)
            }
        }
    }
    
    func photoItem(_ photo: CapturedImage) -> some View {
        Button(action: {
            selectedPhoto = photo
            showingDetailView = true
        }) {
            AsyncImage(url: photo.url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                ProgressView()
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 150, maxHeight: 150)
            .clipped()
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                Text(formatDate(photo.date))
                    .font(.caption)
                    .padding(4)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(4),
                alignment: .bottom
            )
        }
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yy"
        return formatter.string(from: date)
    }
}

struct PhotoDetailView: View {
    let photo: CapturedImage
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            Text(formatFullDate(photo.date))
                .font(.headline)
                .padding()
            
            Spacer()
            
            AsyncImage(url: photo.url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                ProgressView()
            }
            
            Spacer()
            
            Button("Close") {
                presentationMode.wrappedValue.dismiss()
            }
            .padding()
        }
    }
    
    func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
