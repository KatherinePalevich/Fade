import SwiftUI
import SwiftData
import PhotosUI
import ImageIO

struct PhotosPageView: View {
    @Query private var sites: [RashSite]
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var captureDate: Date?
    @State private var flashFired: Bool?
    @State private var showingAssigner = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                let sitesWithPhotos = sites.filter { site in
                    site.entries.contains { $0.photoURL != nil }
                }.sorted { site1, site2 in
                    let last1 = site1.entries.map { $0.timestamp }.max() ?? Date.distantPast
                    let last2 = site2.entries.map { $0.timestamp }.max() ?? Date.distantPast
                    return last1 > last2
                }
                
                if sitesWithPhotos.isEmpty {
                    Text("No photos yet. Tap the + icon to add a photo.")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(sitesWithPhotos) { site in
                        VStack(alignment: .leading) {
                            Text(site.name.isEmpty ? "Rash on \(site.bodySide.rawValue)" : site.name)
                                .font(.headline)
                                .padding(.horizontal)
                            
                            let photos = site.entries
                                .filter { $0.photoURL != nil }
                                .sorted { $0.timestamp < $1.timestamp }
                                
                            TimelapseCarouselView(entries: photos)
                                .frame(height: 300)
                        }
                        .padding(.bottom, 16)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Photos")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Image(systemName: "photo.badge.plus")
                }
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    var extractedDate: Date? = nil
                    var extractedFlash: Bool? = nil
                    
                    if let source = CGImageSourceCreateWithData(data as CFData, nil),
                       let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
                       let exif = metadata[kCGImagePropertyExifDictionary as String] as? [String: Any] {
                        
                        if let dateString = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String {
                            let formatter = DateFormatter()
                            formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                            extractedDate = formatter.date(from: dateString)
                        }
                        
                        if let flash = exif[kCGImagePropertyExifFlash as String] as? Int {
                            extractedFlash = (flash & 1) != 0
                        }
                    }
                    
                    if let uiImage = UIImage(data: data) {
                        let resizedImage = await Task.detached {
                            ImageStore.shared.resizeImage(image: uiImage)
                        }.value
                        
                        captureDate = extractedDate
                        flashFired = extractedFlash
                        selectedImage = resizedImage
                        showingAssigner = true
                    }
                }
                selectedItem = nil // reset
            }
        }
        .sheet(isPresented: $showingAssigner) {
            if let image = selectedImage {
                PhotoAssignerView(newImage: image, captureDate: captureDate, flashFired: flashFired, isPresented: $showingAssigner)
            }
        }
    }
}

struct TimelapseCarouselView: View {
    let entries: [RashEntry]
    
    @State private var currentIndex: Int = 0
    @State private var dragStartIndex: Int? = nil
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if !entries.isEmpty {
                    let currentEntry = entries[currentIndex]
                    if let photoURL = currentEntry.photoURL,
                       let image = ImageStore.shared.loadImage(named: photoURL) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill() // Using fill to ensure it covers the area for a better timelapse effect
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                        Text("Image missing")
                    }
                }
                
                // Overlay for scrubber info
                VStack {
                    Spacer()
                    if !entries.isEmpty {
                        HStack(spacing: 4) {
                            if let flashFired = entries[currentIndex].flashFired {
                                Image(systemName: flashFired ? "bolt.fill" : "bolt.slash.fill")
                            }
                            Text(entries[currentIndex].timestamp, format: .dateTime)
                        }
                        .font(.caption)
                        .padding(6)
                        .background(Color.black.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                        .padding(8)
                    }
                }
            }
            .contentShape(Rectangle()) // ensure gesture covers whole area
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if dragStartIndex == nil {
                            dragStartIndex = currentIndex
                        }
                        
                        let translation = value.translation.width
                        let totalImages = CGFloat(entries.count)
                        if totalImages > 1 {
                            // Relative scrubbing: drag the whole width to scrub through all images
                            let stepWidth = geometry.size.width / totalImages
                            let indexOffset = Int(translation / stepWidth)
                            let newIndex = min(max((dragStartIndex ?? currentIndex) + indexOffset, 0), entries.count - 1)
                            currentIndex = newIndex
                        }
                    }
                    .onEnded { value in
                        dragStartIndex = nil
                        
                        // Treat as a tap if there was little to no movement
                        if abs(value.translation.width) <= 5 && abs(value.translation.height) <= 5 {
                            if value.location.x < geometry.size.width / 2 {
                                // Tap left half
                                if currentIndex > 0 {
                                    currentIndex -= 1
                                }
                            } else {
                                // Tap right half
                                if currentIndex < entries.count - 1 {
                                    currentIndex += 1
                                }
                            }
                        }
                    }
            )
        }
        .background(Color(.systemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}
