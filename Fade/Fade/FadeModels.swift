import Foundation
import SwiftData

enum BodySide: String, Codable, CaseIterable, Identifiable {
    case front = "Front"
    case back = "Back"
    var id: String { rawValue }
}

@Model
final class RashSite {
    var id: UUID
    var normalizedX: Double?
    var normalizedY: Double?
    var bodySideRaw: String
    var name: String = ""
    
    var bodySide: BodySide {
        get { BodySide(rawValue: bodySideRaw) ?? .front }
        set { bodySideRaw = newValue.rawValue }
    }
    
    @Relationship(deleteRule: .cascade, inverse: \RashEntry.site)
    var entries: [RashEntry]
    
    init(id: UUID = UUID(), normalizedX: Double? = nil, normalizedY: Double? = nil, bodySide: BodySide, name: String = "") {
        self.id = id
        self.normalizedX = normalizedX
        self.normalizedY = normalizedY
        self.bodySideRaw = bodySide.rawValue
        self.name = name
        self.entries = []
    }
}

@Model
final class RashEntry {
    var id: UUID
    var timestamp: Date
    var diameterMM: Double
    var photoURL: String?
    var flashFired: Bool?
    
    var site: RashSite?
    
    init(id: UUID = UUID(), timestamp: Date, diameterMM: Double, photoURL: String? = nil, flashFired: Bool? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.diameterMM = diameterMM
        self.photoURL = photoURL
        self.flashFired = flashFired
    }
}

@Model
final class TreatmentLog {
    var id: UUID
    var timestamp: Date
    var medicationName: String
    var wasCleaned: Bool
    var changedUndergarments: Bool = false
    var notes: String
    
    init(id: UUID = UUID(), timestamp: Date, medicationName: String, wasCleaned: Bool, changedUndergarments: Bool = false, notes: String) {
        self.id = id
        self.timestamp = timestamp
        self.medicationName = medicationName
        self.wasCleaned = wasCleaned
        self.changedUndergarments = changedUndergarments
        self.notes = notes
    }
}

import UIKit

class ImageStore {
    static let shared = ImageStore()
    
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    func saveImage(_ image: UIImage, withName name: String) -> URL? {
        let url = documentsDirectory.appendingPathComponent("\(name).jpg")
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        do {
            try data.write(to: url)
            return url
        } catch {
            print("Error saving image: \(error)")
            return nil
        }
    }
    
    func loadImage(named name: String) -> UIImage? {
        let url = documentsDirectory.appendingPathComponent("\(name).jpg")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
    
    func deleteImage(named name: String) {
        let url = documentsDirectory.appendingPathComponent("\(name).jpg")
        try? FileManager.default.removeItem(at: url)
    }
    
    func resizeImage(image: UIImage, targetSize: CGSize = CGSize(width: 1024, height: 1024)) -> UIImage {
        let size = image.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        // If image is already smaller than target, don't resize
        if widthRatio >= 1 && heightRatio >= 1 {
            return image
        }
        
        var newSize: CGSize
        if(widthRatio > heightRatio) {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        }
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    var customSilhouetteURL: URL {
        documentsDirectory.appendingPathComponent("custom_silhouette.png")
    }
    
    func saveCustomSilhouette(_ image: UIImage) -> Bool {
        guard let data = image.pngData() else { return false }
        do {
            try data.write(to: customSilhouetteURL)
            return true
        } catch {
            print("Error saving custom silhouette: \(error)")
            return false
        }
    }
    
    func loadCustomSilhouette() -> UIImage? {
        guard let data = try? Data(contentsOf: customSilhouetteURL) else { return nil }
        return UIImage(data: data)
    }
    
    func deleteCustomSilhouette() {
        try? FileManager.default.removeItem(at: customSilhouetteURL)
    }
    
    func customSilhouetteExists() -> Bool {
        FileManager.default.fileExists(atPath: customSilhouetteURL.path)
    }
}
