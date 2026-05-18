import SwiftUI
import SwiftData

struct PhotoAlignmentView: View {
    @Environment(\.modelContext) private var modelContext
    let oldImage: UIImage
    let newImage: UIImage
    let site: RashSite
    @Binding var isPresented: Bool
    
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    @State private var rotation: Angle = .zero
    @State private var lastRotation: Angle = .zero
    
    @State private var isRendering = false
    
    var body: some View {
        VStack {
            Text("Align the new photo to match the old one")
                .padding()
            
            GeometryReader { geometry in
                let containerSize = geometry.size
                let displaySize = calculateDisplaySize(containerSize: containerSize, imageSize: oldImage.size)
                let displayWidth = displaySize.width
                let displayHeight = displaySize.height
                
                ZStack {
                    // Background old image
                    Image(uiImage: oldImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: displayWidth, height: displayHeight)
                    
                    // The new image on top
                    Image(uiImage: newImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: displayWidth, height: displayHeight)
                        .rotationEffect(rotation)
                        .scaleEffect(scale)
                        .offset(offset)
                        .opacity(0.5) // Light transparency to see the old photo
                        .gesture(
                            MagnifyGesture()
                                .onChanged { value in
                                    scale = lastScale * value.magnification
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                }
                                .simultaneously(with: RotationGesture()
                                    .onChanged { value in
                                        rotation = lastRotation + value
                                    }
                                    .onEnded { _ in
                                        lastRotation = rotation
                                    }
                                )
                                .simultaneously(with: DragGesture()
                                    .onChanged { value in
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                                )
                        )
                }
                .frame(width: containerSize.width, height: containerSize.height)
                .clipped()
                .overlay(alignment: .bottom) {
                    HStack {
                        Button("Cancel") {
                            isPresented = false
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button("Done") {
                            saveAlignedImage(displayWidth: displayWidth, displayHeight: displayHeight)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isRendering)
                    }
                    .padding()
                    .background(Color(.systemBackground).opacity(0.95))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationTitle("Crop & Align")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true) // prevent back during alignment without canceling
    }
    
    @MainActor
    private func saveAlignedImage(displayWidth: CGFloat, displayHeight: CGFloat) {
        isRendering = true
        
        let oldImageSize = oldImage.size
        let displaySize = CGSize(width: displayWidth, height: displayHeight)
        let multiplier = oldImageSize.width / displaySize.width
        
        let renderView = ZStack {
            Color.clear
            Image(uiImage: newImage)
                .resizable()
                .scaledToFit()
                .frame(width: displaySize.width * multiplier, height: displayHeight * multiplier)
                .rotationEffect(rotation)
                .scaleEffect(scale)
                .offset(x: offset.width * multiplier, y: offset.height * multiplier)
        }
        .frame(width: oldImageSize.width, height: oldImageSize.height)
        .clipped()
        
        let renderer = ImageRenderer(content: renderView)
        // Set scale to 1 to match the actual image size coordinates rather than screen scale
        renderer.scale = 1.0
        
        if let renderedCGImage = renderer.cgImage {
            let finalImage = UIImage(cgImage: renderedCGImage)
            
            let photoName = UUID().uuidString
            _ = ImageStore.shared.saveImage(finalImage, withName: photoName)
            
            let entry = RashEntry(timestamp: Date(), diameterMM: 20.0, photoURL: photoName)
            site.entries.append(entry)
            entry.site = site
        }
        
        isPresented = false
    }
    
    private func calculateDisplaySize(containerSize: CGSize, imageSize: CGSize) -> CGSize {
        let oldAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height
        
        if oldAspect > containerAspect {
            return CGSize(width: containerSize.width, height: containerSize.width / oldAspect)
        } else {
            return CGSize(width: containerSize.height * oldAspect, height: containerSize.height)
        }
    }
}
