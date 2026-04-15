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
    var normalizedX: Double
    var normalizedY: Double
    var bodySideRaw: String
    
    var bodySide: BodySide {
        get { BodySide(rawValue: bodySideRaw) ?? .front }
        set { bodySideRaw = newValue.rawValue }
    }
    
    @Relationship(deleteRule: .cascade, inverse: \RashEntry.site)
    var entries: [RashEntry]
    
    init(id: UUID = UUID(), normalizedX: Double, normalizedY: Double, bodySide: BodySide) {
        self.id = id
        self.normalizedX = normalizedX
        self.normalizedY = normalizedY
        self.bodySideRaw = bodySide.rawValue
        self.entries = []
    }
}

@Model
final class RashEntry {
    var id: UUID
    var timestamp: Date
    var diameterMM: Double
    var photoURL: String?
    
    var site: RashSite?
    
    init(id: UUID = UUID(), timestamp: Date, diameterMM: Double, photoURL: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.diameterMM = diameterMM
        self.photoURL = photoURL
    }
}

@Model
final class TreatmentLog {
    var id: UUID
    var timestamp: Date
    var medicationName: String
    var wasCleaned: Bool
    var notes: String
    
    init(id: UUID = UUID(), timestamp: Date, medicationName: String, wasCleaned: Bool, notes: String) {
        self.id = id
        self.timestamp = timestamp
        self.medicationName = medicationName
        self.wasCleaned = wasCleaned
        self.notes = notes
    }
}
