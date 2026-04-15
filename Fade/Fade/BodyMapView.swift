import SwiftUI
import SwiftData

struct BodyMapView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sites: [RashSite]
    
    @State private var selectedSide: BodySide = .front
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    @State private var currentDateFilter: Date = Date()
    @State private var isTimeLapseActive = false
    @State private var availableDates: [Date] = []
    
    @State private var editingEntry: RashEntry?
    
    var body: some View {
        VStack {
            Picker("Body Side", selection: $selectedSide) {
                ForEach(BodySide.allCases) { side in
                    Text(side.rawValue).tag(side)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            GeometryReader { geometry in
                ZStack {
                    Image("HumanSilhouette")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    ForEach(sites.filter { $0.bodySide == selectedSide }) { site in
                        if let entry = getEntry(for: site, at: currentDateFilter) {
                            Circle()
                                .fill(Color.red.opacity(0.6))
                                .frame(width: CGFloat(entry.diameterMM), height: CGFloat(entry.diameterMM))
                                .position(x: site.normalizedX * geometry.size.width,
                                          y: site.normalizedY * geometry.size.height)
                                .onTapGesture {
                                    editingEntry = entry
                                }
                        }
                    }
                    
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture(coordinateSpace: .local) { location in
                            let nx = location.x / geometry.size.width
                            let ny = location.y / geometry.size.height
                            addNewRashSite(at: nx, y: ny)
                        }
                }
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in
                            // simple scale
                            scale = min(max(value.magnification, 1.0), 5.0)
                        }
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
            .clipped()
            
            // Timeline Scrubber
            VStack {
                if !availableDates.isEmpty {
                    Text("Timeline: \(currentDateFilter, format: .dateTime.month().day().year())")
                    HStack {
                        Button(action: toggleTimeLapse) {
                            Image(systemName: isTimeLapseActive ? "pause.circle.fill" : "play.circle.fill")
                                .font(.title)
                        }
                        
                        Slider(value: Binding(get: {
                            currentDateFilter.timeIntervalSince1970
                        }, set: { newValue in
                            currentDateFilter = Date(timeIntervalSince1970: newValue)
                        }), in: availableDates.first!.timeIntervalSince1970...Date().timeIntervalSince1970)
                    }
                } else {
                    Text("Tap to add a rash site.")
                }
            }
            .padding()
        }
        .onAppear {
            updateAvailableDates()
        }
        .sheet(item: Binding<RashEntry?>(
            get: { editingEntry },
            set: { editingEntry = $0 }
        )) { entry in
            RashDetailSheet(entry: entry)
        }
    }
    
    private func addNewRashSite(at x: Double, y: Double) {
        let newSite = RashSite(normalizedX: x, normalizedY: y, bodySide: selectedSide)
        let entry = RashEntry(timestamp: Date(), diameterMM: 20.0)
        newSite.entries.append(entry)
        entry.site = newSite
        modelContext.insert(newSite)
        updateAvailableDates()
        editingEntry = entry
    }
    
    private func getEntry(for site: RashSite, at date: Date) -> RashEntry? {
        site.entries.filter { $0.timestamp <= date }.sorted(by: { $0.timestamp > $1.timestamp }).first
    }
    
    private func updateAvailableDates() {
        let allEntries = sites.flatMap { $0.entries }.sorted(by: { $0.timestamp < $1.timestamp })
        guard let first = allEntries.first?.timestamp else { return }
        
        availableDates = [first, Date()]
        currentDateFilter = Date()
    }
    
    private func toggleTimeLapse() {
        isTimeLapseActive.toggle()
        if isTimeLapseActive && !availableDates.isEmpty {
            let end = Date().timeIntervalSince1970
            
            if currentDateFilter.timeIntervalSince1970 >= end - 86400 {
                // If at the end, restart
                currentDateFilter = availableDates.first!
            }
            
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                if !isTimeLapseActive {
                    timer.invalidate()
                    return
                }
                let nextTime = currentDateFilter.timeIntervalSince1970 + 86400 * 2 // +2 days per tick
                if nextTime > end {
                    isTimeLapseActive = false
                    timer.invalidate()
                    currentDateFilter = Date()
                } else {
                    currentDateFilter = Date(timeIntervalSince1970: nextTime)
                }
            }
        }
    }
}



struct RashDetailSheet: View {
    @Bindable var entry: RashEntry
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Rash Size")) {
                    Slider(value: $entry.diameterMM, in: 5...100, step: 1)
                    Text("Diameter: \(entry.diameterMM, specifier: "%.0f") mm")
                }
                
                Button("Done") {
                    dismiss()
                }
            }
            .navigationTitle("Edit Rash")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}
