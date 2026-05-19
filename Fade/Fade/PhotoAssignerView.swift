import SwiftUI
import SwiftData

struct PhotoAssignerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sites: [RashSite]
    
    let newImage: UIImage
    var captureDate: Date? = nil
    var flashFired: Bool? = nil
    @Binding var isPresented: Bool
    
    @State private var isCreatingNew = false
    @State private var newSiteName = ""
    @State private var selectedBodySide: BodySide = .front
    
    @State private var siteForAlignment: RashSite?
    @State private var oldImageForAlignment: UIImage?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Create New Rash Site", isOn: $isCreatingNew)
                }
                
                if isCreatingNew {
                    Section(header: Text("New Rash Details")) {
                        TextField("Rash Name (e.g. Left Arm)", text: $newSiteName)
                        Picker("Body Side", selection: $selectedBodySide) {
                            ForEach(BodySide.allCases) { side in
                                Text(side.rawValue).tag(side)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        Button("Save Photo") {
                            saveToNewSite()
                        }
                        .disabled(newSiteName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } else {
                    Section(header: Text("Select Existing Rash Site")) {
                        let sortedSites = sites.sorted { site1, site2 in
                            let last1 = site1.entries.map { $0.timestamp }.max() ?? Date.distantPast
                            let last2 = site2.entries.map { $0.timestamp }.max() ?? Date.distantPast
                            return last1 > last2
                        }
                        if sortedSites.isEmpty {
                            Text("No existing sites.")
                                .foregroundColor(.secondary)
                        }
                        ForEach(sortedSites) { site in
                            Button(action: {
                                handleSiteSelection(site)
                            }) {
                                HStack {
                                    if let lastPhotoURL = site.entries.sorted(by: { $0.timestamp > $1.timestamp }).first(where: { $0.photoURL != nil })?.photoURL,
                                       let img = ImageStore.shared.loadImage(named: lastPhotoURL) {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 40, height: 40)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } else {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 40, height: 40)
                                            .overlay(Image(systemName: "photo").foregroundColor(.gray))
                                    }
                                    
                                    VStack(alignment: .leading) {
                                        Text(site.name.isEmpty ? "Rash on \(site.bodySide.rawValue)" : site.name)
                                            .foregroundColor(.primary)
                                        Text("\(site.entries.count) logs")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Assign Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .navigationDestination(item: $siteForAlignment) { site in
                if let oldImg = oldImageForAlignment {
                    PhotoAlignmentView(oldImage: oldImg, newImage: newImage, site: site, captureDate: captureDate, flashFired: flashFired, isPresented: $isPresented)
                }
            }
        }
    }
    
    private func saveToNewSite() {
        let newSite = RashSite(bodySide: selectedBodySide, name: newSiteName)
        modelContext.insert(newSite)
        
        let photoName = UUID().uuidString
        _ = ImageStore.shared.saveImage(newImage, withName: photoName)
        
        let entry = RashEntry(timestamp: captureDate ?? Date(), diameterMM: 20.0, photoURL: photoName, flashFired: flashFired)
        newSite.entries.append(entry)
        entry.site = newSite
        
        isPresented = false
    }
    
    private func handleSiteSelection(_ site: RashSite) {
        if let lastPhotoEntry = site.entries.sorted(by: { $0.timestamp > $1.timestamp }).first(where: { $0.photoURL != nil }),
           let photoURL = lastPhotoEntry.photoURL,
           let oldImage = ImageStore.shared.loadImage(named: photoURL) {
            
            self.oldImageForAlignment = oldImage
            self.siteForAlignment = site
        } else {
            let photoName = UUID().uuidString
            _ = ImageStore.shared.saveImage(newImage, withName: photoName)
            
            let entry = RashEntry(timestamp: captureDate ?? Date(), diameterMM: 20.0, photoURL: photoName, flashFired: flashFired)
            site.entries.append(entry)
            entry.site = site
            
            isPresented = false
        }
    }
}
