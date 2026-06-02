import SwiftUI
import PhotosUI

struct SilhouetteTracerView: View {
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("customSilhouetteVersion") private var customSilhouetteVersion: Int = 0
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var isLoadingImage = false
    @State private var isPastedImage = false
    @State private var showingPasteError = false
    
    // Mode selection: Adjust photo vs trace outline
    enum EditModeState: String, CaseIterable, Identifiable {
        case adjust = "Adjust Photo"
        case trace = "Trace Outline"
        var id: String { rawValue }
    }
    @State private var mode: EditModeState = .adjust
    @State private var isPreviewing = false
    
    // Photo Adjustment States
    @State private var photoScale: CGFloat = 1.0
    @State private var lastPhotoScale: CGFloat = 1.0
    @State private var photoOffset: CGSize = .zero
    @State private var lastPhotoOffset: CGSize = .zero
    
    // Tracing States
    @State private var points: [CGPoint] = []
    @State private var history: [[CGPoint]] = []
    @State private var isDrawing = false
    
    // Deletion confirmation
    @State private var showingDeleteConfirmation = false
    
    // Dimensions of the canvas
    private let canvasHeight: CGFloat = 550
    private let canvasWidth: CGFloat = 300
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                if selectedImage != nil {
                    headerView
                }
                
                canvasView
                
                if selectedImage != nil {
                    drawingToolbar
                }
            }
            .padding()
        }
        .navigationTitle("Upload Silhouette")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(selectedImage != nil)
        .toolbar {
            if selectedImage != nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: {
                        selectedImage = nil
                        selectedItem = nil
                        isPastedImage = false
                        points = []
                        history = []
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Photos")
                        }
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSilhouette()
                    }
                    .disabled(!isPastedImage && points.count <= 2)
                }
            }
        }
        .onChange(of: selectedItem) { oldValue, newValue in
            guard let newValue else { return }
            isLoadingImage = true
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        selectedImage = uiImage
                        // Reset all editing states on new photo select
                        isPastedImage = false
                        points = []
                        history = []
                        photoScale = 1.0
                        lastPhotoScale = 1.0
                        photoOffset = .zero
                        lastPhotoOffset = .zero
                        mode = .adjust
                        isPreviewing = false
                        isLoadingImage = false
                    }
                } else {
                    await MainActor.run {
                        isLoadingImage = false
                    }
                }
            }
        }
        .confirmationDialog("Delete Custom Silhouette?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                ImageStore.shared.deleteCustomSilhouette()
                customSilhouetteVersion += 1
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will revert your body map silhouette to the default human body image. This action cannot be undone.")
        }
        .alert("Clipboard Empty", isPresented: $showingPasteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("No image found in clipboard. Please copy a subject/figure from your Photos app (long press a subject in a photo and tap Copy) then try again.")
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var headerView: some View {
        VStack(spacing: 8) {
            if isPastedImage {
                Text("Position Your Silhouette")
                    .font(.headline)
                Text("Pinch to zoom and drag to position your pasted silhouette.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else {
                Picker("Mode", selection: $mode) {
                    ForEach(EditModeState.allCases) { state in
                        Text(state.rawValue).tag(state)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                Text(mode == .adjust ? "Pinch to zoom and drag to position your body in the frame." : "Drag your finger to trace the outline of your standing body.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding(.bottom, 8)
    }
    
    @ViewBuilder
    private var canvasView: some View {
        ZStack {
            if isLoadingImage {
                ProgressView("Loading image...")
                    .frame(width: canvasWidth, height: canvasHeight)
            } else if let selectedImage = selectedImage {
                if isPreviewing {
                    silhouettePreviewView
                } else {
                    photoTraceView(selectedImage)
                }
            } else {
                emptyStateView
            }
        }
        .frame(width: canvasWidth)
        .frame(height: selectedImage != nil || isLoadingImage ? canvasHeight : nil)
        .frame(minHeight: selectedImage != nil || isLoadingImage ? nil : canvasHeight)
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var silhouettePreviewView: some View {
        Color.white
        if isPastedImage, let selectedImage = selectedImage {
            // Render the centered pasted silhouette directly
            ZStack {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: canvasWidth, height: canvasHeight)
                    .scaleEffect(photoScale)
                    .offset(photoOffset)
            }
            .frame(width: canvasWidth, height: canvasHeight)
            .clipped()
        } else {
            Path { path in
                guard !points.isEmpty else { return }
                path.addLines(points)
                path.closeSubpath()
            }
            .fill(Color.black)
        }
    }
    
    @ViewBuilder
    private func photoTraceView(_ image: UIImage) -> some View {
        ZStack {
            // Display user photo/silhouette with offset and scale modifiers
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: canvasWidth, height: canvasHeight)
                .scaleEffect(photoScale)
                .offset(photoOffset)
            
            if !isPastedImage {
                // Transparent screen-shade to make drawing lines pop
                Color.black.opacity(0.2)
                    .allowsHitTesting(false)
                
                // Current drawn path
                Path { path in
                    guard !points.isEmpty else { return }
                    path.addLines(points)
                }
                .stroke(Color.cyan, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                
                // Drawing indicators (starting point and closing line helper)
                if let startPoint = points.first {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                        .position(startPoint)
                    
                    if let lastPoint = points.last, points.count > 1 {
                        Path { path in
                            path.move(to: lastPoint)
                            path.addLine(to: startPoint)
                        }
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 2, dash: [5]))
                    }
                }
                
                // Active drawing zone
                if mode == .trace {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(traceGesture)
                }
            }
        }
        .frame(width: canvasWidth, height: canvasHeight)
        .contentShape(Rectangle())
        .gesture(mode == .adjust || isPastedImage ? adjustGesture : nil)
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            if ImageStore.shared.customSilhouetteExists() {
                VStack(spacing: 12) {
                    Text("Current Silhouette")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let customImg = ImageStore.shared.loadCustomSilhouette() {
                        Image(uiImage: customImg)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 240)
                            .background(Color.white)
                            .cornerRadius(8)
                            .shadow(color: Color.black.opacity(0.15), radius: 4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                    }
                    
                    Button(role: .destructive, action: {
                        showingDeleteConfirmation = true
                    }) {
                        Label("Revert to Default", systemImage: "arrow.uturn.backward.circle")
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 4)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            } else {
                Image(systemName: "figure.stand")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 8) {
                Text("Trace Your Own Silhouette")
                    .font(.headline)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text("Select a photo to trace, or copy a subject/figure from your photos and paste it here.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 12) {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    HStack {
                        Image(systemName: "photo.badge.plus")
                        Text("Select Photo")
                    }
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(24)
                }
                
                Button(action: pasteFromClipboard) {
                    HStack {
                        Image(systemName: "doc.on.clipboard")
                        Text("Paste Silhouette")
                    }
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray5))
                    .foregroundColor(.blue)
                    .cornerRadius(24)
                }
            }
            .padding(.bottom, 24)
        }
    }
    
    @ViewBuilder
    private var drawingToolbar: some View {
        if !isPastedImage {
            HStack(spacing: 20) {
                Button(action: {
                    if !history.isEmpty {
                        points = history.removeLast()
                    }
                }) {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                        .fontWeight(.medium)
                }
                .disabled(history.isEmpty)
                .buttonStyle(.bordered)
                
                Button(action: {
                    history.append(points)
                    points = []
                }) {
                    Label("Clear", systemImage: "trash")
                        .fontWeight(.medium)
                }
                .disabled(points.isEmpty)
                .buttonStyle(.bordered)
                
                Toggle(isOn: $isPreviewing) {
                    Label("Preview", systemImage: "eye")
                        .fontWeight(.medium)
                }
                .toggleStyle(.button)
                .disabled(points.isEmpty)
            }
            .padding(.top, 4)
        } else {
            HStack(spacing: 20) {
                Toggle(isOn: $isPreviewing) {
                    Label("Preview", systemImage: "eye")
                        .fontWeight(.medium)
                }
                .toggleStyle(.button)
            }
            .padding(.top, 4)
        }
    }
    
    // MARK: - Gestures
    
    // Gestures for image zoom/pan
    private var adjustGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                photoOffset = CGSize(
                    width: lastPhotoOffset.width + value.translation.width,
                    height: lastPhotoOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastPhotoOffset = photoOffset
            }
            .simultaneously(with:
                MagnifyGesture()
                    .onChanged { value in
                        photoScale = lastPhotoScale * value.magnification
                    }
                    .onEnded { _ in
                        lastPhotoScale = photoScale
                    }
            )
    }
    
    // Gesture for drawing points
    private var traceGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isDrawing {
                    isDrawing = true
                    if history.count > 30 {
                        history.removeFirst()
                    }
                    history.append(points)
                }
                
                // Clamp coordinates to canvas bounds
                let x = max(0, min(value.location.x, canvasWidth))
                let y = max(0, min(value.location.y, canvasHeight))
                points.append(CGPoint(x: x, y: y))
            }
            .onEnded { _ in
                isDrawing = false
            }
    }
    
    // MARK: - Helper Methods
    
    // Paste image from system clipboard and process into silhouette
    private func pasteFromClipboard() {
        if let clipboardImage = UIPasteboard.general.image {
            // Process the image: convert all non-transparent pixels to solid black
            if let processedImage = convertToBlackSilhouette(image: clipboardImage) {
                selectedImage = processedImage
                isPastedImage = true
                mode = .adjust
                points = []
                history = []
                photoScale = 1.0
                lastPhotoScale = 1.0
                photoOffset = .zero
                lastPhotoOffset = .zero
                isPreviewing = false
            }
        } else {
            showingPasteError = true
        }
    }
    
    // Converts any image's non-transparent pixels to black, preserving alpha levels
    private func convertToBlackSilhouette(image: UIImage) -> UIImage? {
        let size = image.size
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            context.cgContext.clear(rect)
            
            // Draw image to define shape alpha
            image.draw(in: rect)
            
            // Re-draw in sourceIn blend mode to tint all visible pixels black
            context.cgContext.setBlendMode(.sourceIn)
            UIColor.black.setFill()
            context.cgContext.fill(rect)
        }
    }
    
    // Main routing to save the active silhouette type
    private func saveSilhouette() {
        if isPastedImage {
            savePastedSilhouette()
        } else {
            saveTracedSilhouette()
        }
    }
    
    // Save panned and zoomed pasted silhouette as a final canvas PNG file
    private func savePastedSilhouette() {
        let size = CGSize(width: canvasWidth, height: canvasHeight)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        guard let image = selectedImage else { return }
        
        let silhouette = renderer.image { context in
            // Clear context background to preserve transparency
            context.cgContext.clear(CGRect(origin: .zero, size: size))
            
            // Reconstruct exact aspect ratio centering matching scaledToFill
            let imageSize = image.size
            let widthRatio = size.width / imageSize.width
            let heightRatio = size.height / imageSize.height
            let ratio = max(widthRatio, heightRatio)
            
            let newWidth = imageSize.width * ratio
            let newHeight = imageSize.height * ratio
            
            let x = (size.width - newWidth) / 2 + photoOffset.width
            let y = (size.height - newHeight) / 2 + photoOffset.height
            
            // Center zoom translation
            context.cgContext.translateBy(x: size.width / 2, y: size.height / 2)
            context.cgContext.scaleBy(x: photoScale, y: photoScale)
            context.cgContext.translateBy(x: -size.width / 2, y: -size.height / 2)
            
            let drawRect = CGRect(x: x, y: y, width: newWidth, height: newHeight)
            image.draw(in: drawRect)
        }
        
        let saved = ImageStore.shared.saveCustomSilhouette(silhouette)
        if saved {
            customSilhouetteVersion += 1
            dismiss()
        }
    }
    
    // Save standard finger-drawn tracing outline as a filled black shape PNG
    private func saveTracedSilhouette() {
        let size = CGSize(width: canvasWidth, height: canvasHeight)
        let renderer = UIGraphicsImageRenderer(size: size)
        let silhouette = renderer.image { context in
            // Clear context background to preserve transparency
            context.cgContext.clear(CGRect(origin: .zero, size: size))
            
            guard points.count > 2 else { return }
            
            context.cgContext.beginPath()
            context.cgContext.move(to: points[0])
            for i in 1..<points.count {
                context.cgContext.addLine(to: points[i])
            }
            context.cgContext.closePath()
            
            UIColor.black.setFill()
            context.cgContext.fillPath()
        }
        
        let saved = ImageStore.shared.saveCustomSilhouette(silhouette)
        if saved {
            customSilhouetteVersion += 1
            dismiss()
        }
    }
}
