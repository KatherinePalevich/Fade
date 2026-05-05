import SwiftUI
import SwiftData

struct BodyMapView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sites: [RashSite]
    
    @AppStorage("waistWidthCM") private var waistWidthCM: Double = 32.0
    @State private var showingMeasurementSettings = false
    
    @Binding var activeTreatmentContext: TreatmentLog?
    @Binding var isEditMode: Bool
    
    @State private var selectedSide: BodySide = .front
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    @State private var currentDateFilter: Date = Date()
    @State private var isTimeLapseActive = false
    @State private var availableDates: [Date] = []
    
    @State private var editingEntry: RashEntry?
    @State private var viewingEntry: RashEntry?
    @State private var currentlyAddingEntry: RashEntry?
    
    var body: some View {
        VStack {
            if isEditMode {
                VStack(spacing: 4) {
                    if let context = activeTreatmentContext {
                        Text("Modifying Rashes")
                            .font(.headline)
                        Text("\(context.timestamp, format: .dateTime) - \(context.medicationName)")
                            .font(.subheadline)
                    } else {
                        Text("Modifying Rashes")
                            .font(.headline)
                    }
                    
                    Button("Done") {
                        isEditMode = false
                        activeTreatmentContext = nil
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.yellow.opacity(0.3))
            }
            
            HStack {
                Button(action: {
                    showingMeasurementSettings = true
                }) {
                    Image(systemName: "ruler")
                }
                .buttonStyle(.bordered)
                
                Picker("Body Side", selection: $selectedSide) {
                    ForEach(BodySide.allCases) { side in
                        Text(side.rawValue).tag(side)
                    }
                }
                .pickerStyle(.segmented)
                
                if !isEditMode {
                    Button("Edit Rashes") {
                        isEditMode = true
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            
            GeometryReader { geometry in
                ZStack {
                    Color.white.ignoresSafeArea()
                    
                    Image("HumanSilhouette")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture(coordinateSpace: .local) { location in
                            if isEditMode {
                                let nx = location.x / geometry.size.width
                                let ny = location.y / geometry.size.height
                                addNewRashSite(at: nx, y: ny)
                            } else {
                                viewingEntry = nil
                            }
                        }
                    
                    ForEach(sites.filter { $0.bodySide == selectedSide }) { site in
                        if let entry = getEntry(for: site, at: currentDateFilter) {
                            let isActive = entry.diameterMM > 0
                            let displayDiameter = isActive ? entry.diameterMM : (getLastNonZeroDiameter(for: site, before: entry.timestamp) ?? 20.0)
                            
                            let displayDiameterPoints = (displayDiameter / (waistWidthCM * 10.0)) * geometry.size.width
                            
                            ZStack {
                                if isActive {
                                    Circle()
                                        .fill(Color.red.opacity(0.6))
                                } else {
                                    Image(systemName: "plus")
                                        .resizable()
                                        .scaledToFit()
                                        .fontWeight(.bold)
                                        .foregroundColor(.green)
                                }
                            }
                            .frame(width: CGFloat(displayDiameterPoints), height: CGFloat(displayDiameterPoints))
                                .position(x: site.normalizedX * geometry.size.width,
                                          y: site.normalizedY * geometry.size.height)
                                .onTapGesture {
                                    if isEditMode {
                                        if let context = activeTreatmentContext {
                                            if let existing = site.entries.first(where: { $0.timestamp == context.timestamp }) {
                                                currentlyAddingEntry = nil
                                                editingEntry = existing
                                            } else {
                                                let newEntry = RashEntry(timestamp: context.timestamp, diameterMM: entry.diameterMM)
                                                site.entries.append(newEntry)
                                                newEntry.site = site
                                                updateAvailableDates()
                                                currentlyAddingEntry = newEntry
                                                editingEntry = newEntry
                                            }
                                        } else {
                                            currentlyAddingEntry = nil
                                            editingEntry = entry
                                        }
                                    } else {
                                        viewingEntry = entry
                                    }
                                }
                        }
                    }
                }
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in
                            let newScale = lastScale * value.magnification
                            scale = min(max(newScale, 1.0), 20.0)
                        }
                        .onEnded { value in
                            lastScale = scale
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
            .contentShape(Rectangle())
            .clipped()
            .overlay {
                if let viewEntry = viewingEntry,
                   let firstEntry = viewEntry.site?.entries.sorted(by: { $0.timestamp < $1.timestamp }).first,
                   let latestEntry = viewEntry.site?.entries.sorted(by: { $0.timestamp < $1.timestamp }).last {
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rash Info")
                            .font(.headline)
                        
                        Text("First Logged: \(firstEntry.timestamp, format: .dateTime.month().day().year().hour().minute())")
                        Text("Last Modified: \(latestEntry.timestamp, format: .dateTime.month().day().year().hour().minute())")
                        Text("Current Size: \(viewEntry.diameterMM, specifier: "%.0f") mm")
                    }
                    .padding()
                    .background(Color(.systemBackground).opacity(0.95))
                    .cornerRadius(12)
                    .shadow(radius: 5)
                }
            }
            
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
        .sheet(isPresented: $showingMeasurementSettings) {
            WaistMeasurementSettingsView()
        }
        .sheet(item: Binding<RashEntry?>(
            get: { editingEntry },
            set: { editingEntry = $0 }
        )) { entry in
            RashDetailSheet(entry: entry, onDeleteSite: {
                if let site = entry.site {
                    modelContext.delete(site)
                }
                editingEntry = nil
                currentlyAddingEntry = nil
            }, onCancel: {
                if let newEntry = currentlyAddingEntry {
                    if let site = newEntry.site, site.entries.count <= 1 {
                        modelContext.delete(site)
                    } else {
                        modelContext.delete(newEntry)
                    }
                }
                editingEntry = nil
                currentlyAddingEntry = nil
            }, onDone: {
                editingEntry = nil
                currentlyAddingEntry = nil
            })
        }
    }
    
    private func addNewRashSite(at x: Double, y: Double) {
        let newSite = RashSite(normalizedX: x, normalizedY: y, bodySide: selectedSide)
        let timestamp = activeTreatmentContext?.timestamp ?? Date()
        let entry = RashEntry(timestamp: timestamp, diameterMM: 20.0)
        newSite.entries.append(entry)
        entry.site = newSite
        modelContext.insert(newSite)
        updateAvailableDates()
        currentlyAddingEntry = entry
        editingEntry = entry
    }
    
    private func getEntry(for site: RashSite, at date: Date) -> RashEntry? {
        site.entries.filter { $0.timestamp <= date }.sorted(by: { $0.timestamp > $1.timestamp }).first
    }
    
    private func getLastNonZeroDiameter(for site: RashSite, before date: Date) -> Double? {
        site.entries
            .filter { $0.timestamp <= date && $0.diameterMM > 0 }
            .sorted(by: { $0.timestamp > $1.timestamp })
            .first?.diameterMM
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
    
    var onDeleteSite: () -> Void
    var onCancel: () -> Void
    var onDone: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Rash Size")) {
                    Slider(value: $entry.diameterMM, in: 0...100, step: 1)
                    Text("Diameter: \(entry.diameterMM, specifier: "%.0f") mm")
                }
                
                Section {
                    Button(role: .destructive) {
                        entry.diameterMM = 0
                        onDone()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Rash Disappeared / Healed")
                            Spacer()
                        }
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        onDeleteSite()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Rash Completely")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Rash")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct WaistMeasurementSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("waistWidthCM") private var waistWidthCM: Double = 32.0
    
    @State private var inputValue: String = ""
    @State private var isCm: Bool = true
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Waist Width"), footer: Text("Set your waist width so that rash sizes appear proportional to your body on the map.")) {
                    HStack {
                        TextField("Measurement", text: $inputValue)
                            .keyboardType(.decimalPad)
                        
                        Picker("Unit", selection: $isCm) {
                            Text("cm").tag(true)
                            Text("inches").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                    }
                }
            }
            .navigationTitle("Measurement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                }
            }
            .onAppear {
                inputValue = String(format: "%.1f", isCm ? waistWidthCM : waistWidthCM / 2.54)
            }
            .onChange(of: isCm) { oldValue, newValue in
                if let val = Double(inputValue) {
                    if newValue { // inches to cm
                        inputValue = String(format: "%.1f", val * 2.54)
                    } else { // cm to inches
                        inputValue = String(format: "%.1f", val / 2.54)
                    }
                }
            }
        }
        .presentationDetents([.fraction(0.35)])
    }
    
    private func save() {
        // Convert comma to dot for decimal parsing in some locales
        let sanitizedInput = inputValue.replacingOccurrences(of: ",", with: ".")
        if let val = Double(sanitizedInput) {
            waistWidthCM = isCm ? val : val * 2.54
        }
        dismiss()
    }
}
