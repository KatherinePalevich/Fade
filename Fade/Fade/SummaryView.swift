import SwiftUI
import SwiftData
import Charts

fileprivate func colorForMedication(_ name: String) -> Color {
    switch name {
    case "Terbinafine 1%": return .purple
    case "Clotrimazole 1%": return .orange
    case "Ketoconazole 2%": return .mint
    default: return .pink
    }
}

struct SummaryView: View {
    @Binding var selectedTab: Int
    @Binding var editingTreatmentLog: TreatmentLog?
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RashEntry.timestamp) private var entries: [RashEntry]
    @Query(sort: \TreatmentLog.timestamp) private var treatments: [TreatmentLog]
    @Query private var sites: [RashSite]
    
    @ObservedObject private var medicationSettings = MedicationFrequencySettings.shared
    
    enum RashFilterState: String, CaseIterable, Identifiable {
        case active = "Active"
        case healed = "Healed"
        var id: String { self.rawValue }
    }
    
    @State private var filterState: RashFilterState = .active
    @State private var showingResetAlert = false
    @State private var showingNotificationSettings = false
    
    @State private var calendarDate: Date = Date()
    @State private var selectedTreatmentDate: Date?
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    TreatmentCalendarView(
                        calendarDate: $calendarDate,
                        selectedTreatmentDate: $selectedTreatmentDate,
                        treatments: treatments
                    )
                } header: {
                    Text("Treatment Calendar")
                }
                
                Section {
                    if entries.isEmpty {
                        Text("No data to show.")
                            .padding()
                    } else {
                        VStack {
                            Chart {
                                let aggregated = aggregateEntriesByDay(entries: entries)
                                
                                let firstTreatmentDate = treatments.min(by: { $0.timestamp < $1.timestamp })?.timestamp
                                let firstRecordedRashDate = entries.filter { $0.photoURL == nil }.min(by: { $0.timestamp < $1.timestamp })?.timestamp
                                let cutoffDate = Calendar.current.startOfDay(for: firstTreatmentDate ?? firstRecordedRashDate ?? Date.distantPast)
                                
                                let filteredAggregated = aggregated.filter { $0.key >= cutoffDate }
                                
                                ForEach(filteredAggregated.sorted(by: { $0.key < $1.key }), id: \.key) { date, area in
                                    LineMark(
                                        x: .value("Date", date),
                                        y: .value("Total Area (mm²)", area)
                                    )
                                    .foregroundStyle(.red)
                                    
                                    PointMark(
                                        x: .value("Date", date),
                                        y: .value("Total Area (mm²)", area)
                                    )
                                    .foregroundStyle(.red)
                                }
                                
                                ForEach(treatments) { treatment in
                                    PointMark(
                                        x: .value("Treatment Date", treatment.timestamp),
                                        y: .value("Treatment", 0)
                                    )
                                    .foregroundStyle(.blue)
                                    .annotation(position: .bottom) {
                                        Image(systemName: "cross.fill")
                                            .foregroundColor(.blue)
                                            .font(.caption)
                                    }
                                }
                            }
                            .frame(height: 300)
                            .padding(.top)
                            
                            Text("Healing Progress vs Treatments")
                                .font(.headline)
                            
                            HStack(spacing: 16) {
                                HStack(spacing: 4) {
                                    Circle().fill(.red).frame(width: 8, height: 8)
                                    Text("Total Rash Area").font(.caption).foregroundColor(.secondary)
                                }
                                HStack(spacing: 4) {
                                    Image(systemName: "cross.fill").foregroundColor(.blue).font(.caption2)
                                    Text("Treatment Logged").font(.caption).foregroundColor(.secondary)
                                }
                            }
                            .padding(.bottom)
                        }
                    }
                } header: {
                    Text("Progress")
                }
                
                insightsSection
                
                Section {
                    Picker("Filter State", selection: $filterState) {
                        ForEach(RashFilterState.allCases) { state in
                            Text(state.rawValue).tag(state)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 8)
                    
                    ForEach(filteredSites) { site in
                        siteRow(for: site)
                    }
                    .onDelete(perform: deleteSites)
                    
                    if filteredSites.isEmpty {
                        Text("No \(filterState.rawValue.lowercased()) rashes found.")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Logged Rashes")
                }
            }
            .navigationTitle("Summary")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingNotificationSettings = true
                    } label: {
                        Image(systemName: "bell")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showingResetAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            .alert("Factory Reset", isPresented: $showingResetAlert) {
                Button("Delete All Data", role: .destructive) {
                    resetSystem()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete all historical logs, active rashes, and treatment histories? This action cannot be undone.")
            }
            .sheet(isPresented: $showingNotificationSettings) {
                NotificationSettingsView()
            }
        }
        .overlay {
            if let selectedDate = selectedTreatmentDate {
                treatmentOverlay(for: selectedDate)
            }
        }
    }
    
    @ViewBuilder
    private func treatmentOverlay(for date: Date) -> some View {
        let dayTreatments = treatments.filter { Calendar.current.isDate($0.timestamp, inSameDayAs: date) }
        
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    selectedTreatmentDate = nil
                }
            
            VStack {
                HStack {
                    Text(date, format: .dateTime.month().day().year())
                        .font(.headline)
                    Spacer()
                    Button {
                        selectedTreatmentDate = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.title2)
                    }
                }
                .padding()
                
                if dayTreatments.isEmpty {
                    Text("No treatments remaining.")
                        .padding()
                        .onAppear {
                            selectedTreatmentDate = nil
                        }
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(dayTreatments) { treatment in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(treatment.medicationName)
                                        .font(.headline)
                                        .foregroundColor(colorForMedication(treatment.medicationName))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                    
                                    Text(treatment.timestamp, format: .dateTime.hour().minute())
                                        .font(.subheadline)
                                    
                                    if treatment.wasCleaned {
                                        HStack(spacing: 4) {
                                            Image(systemName: "drop.fill").foregroundColor(.blue)
                                            Text("After shower").font(.caption)
                                        }
                                    }
                                    
                                    if treatment.changedUndergarments {
                                        HStack(spacing: 4) {
                                            Image(systemName: "tshirt.fill").foregroundColor(.brown)
                                            Text("Changed clothes").font(.caption)
                                        }
                                    }
                                    
                                    if !treatment.notes.isEmpty {
                                        Text(treatment.notes)
                                            .font(.caption)
                                            .italic()
                                            .lineLimit(3)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(role: .destructive) {
                                        modelContext.delete(treatment)
                                        // The view will reactively update. If all treatments are deleted,
                                        // the array becomes empty and the overlay dismisses itself via onAppear logic above,
                                        // but we can also explicitly dismiss if it was the last one.
                                        if dayTreatments.count == 1 {
                                            selectedTreatmentDate = nil
                                        }
                                    } label: {
                                        HStack {
                                            Spacer()
                                            Image(systemName: "trash")
                                            Text("Delete")
                                            Spacer()
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                                .padding()
                                .frame(width: 200, height: 220)
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .cornerRadius(12)
                                .shadow(radius: 2)
                                .onTapGesture {
                                    editingTreatmentLog = treatment
                                    selectedTab = 1
                                    selectedTreatmentDate = nil
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .cornerRadius(16)
            .padding()
        }
    }
    
    private var filteredSites: [RashSite] {
        sites.filter { site in
            let latestDiameter = site.entries.sorted(by: { $0.timestamp < $1.timestamp }).last?.diameterMM ?? 0
            if filterState == .active {
                return latestDiameter > 0
            } else {
                return latestDiameter == 0 && !site.entries.isEmpty
            }
        }
    }
    
    @ViewBuilder
    private func siteRow(for site: RashSite) -> some View {
        let sorted = site.entries.sorted(by: { $0.timestamp < $1.timestamp })
        if let first = sorted.first, let last = sorted.last {
            VStack(alignment: .leading, spacing: 6) {
                Text("Body Side: \(site.bodySide.rawValue)")
                    .font(.headline)
                HStack {
                    Text("First Logged:")
                    Spacer()
                    Text("\(first.timestamp, format: .dateTime.month().day().year())")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                
                HStack {
                    Text("Current Size:")
                    Spacer()
                    Text("\(last.diameterMM, specifier: "%.0f") mm")
                        .foregroundColor(last.diameterMM == 0 ? .green : .primary)
                }
                .font(.subheadline)
            }
            .padding(.vertical, 4)
        }
    }
    
    private func deleteSites(at offsets: IndexSet) {
        for index in offsets {
            let site = filteredSites[index]
            modelContext.delete(site)
        }
    }
    
    private func resetSystem() {
        for site in sites {
            modelContext.delete(site)
        }
        for treatment in treatments {
            modelContext.delete(treatment)
        }
    }
    
    private func aggregateEntriesByDay(entries: [RashEntry]) -> [Date: Double] {
        var dailyTotals: [Date: Double] = [:]
        let calendar = Calendar.current
        var allDates = Set<Date>()
        for entry in entries {
            allDates.insert(calendar.startOfDay(for: entry.timestamp))
        }
        allDates.insert(calendar.startOfDay(for: Date()))
        
        for date in allDates {
            var totalArea: Double = 0
            var siteDict: [UUID: Double] = [:]
            for e in entries where e.timestamp <= date.addingTimeInterval(86400) {
                if let siteId = e.site?.id {
                    siteDict[siteId] = e.diameterMM
                }
            }
            
            for d in siteDict.values {
                totalArea += Double.pi * pow(d / 2.0, 2)
            }
            dailyTotals[date] = totalArea
        }
        
        return dailyTotals
    }
    
    private var insightsSection: some View {
        Section(header: Text("Insights")) {
            // Washed Before Treatment
            let washCount = treatments.filter { $0.wasCleaned }.count
            let washPercent = treatments.isEmpty ? 0 : Int(Double(washCount) / Double(treatments.count) * 100)
            HStack {
                Text("Washed Before Treatment")
                Spacer()
                Text("\(washPercent)%")
                    .foregroundColor(.secondary)
            }
            
            // Changed Undergarments
            let undergarmentCount = treatments.filter { $0.changedUndergarments }.count
            let undergarmentPercent = treatments.isEmpty ? 0 : Int(Double(undergarmentCount) / Double(treatments.count) * 100)
            HStack {
                Text("Changed Undergarments")
                Spacer()
                Text("\(undergarmentPercent)%")
                    .foregroundColor(.secondary)
            }
            
            // Photo Documentation Frequency
            let entriesWithPhotos = entries.filter { $0.photoURL != nil }.sorted(by: { $0.timestamp < $1.timestamp })
            if entriesWithPhotos.count > 1 {
                let totalInterval = entriesWithPhotos.last!.timestamp.timeIntervalSince(entriesWithPhotos.first!.timestamp)
                let avgInterval = totalInterval / Double(entriesWithPhotos.count - 1)
                
                HStack {
                    Text("New Photo Frequency")
                    Spacer()
                    if avgInterval < 86400 {
                        Text(String(format: "Every %.1f hours", avgInterval / 3600))
                            .foregroundColor(.secondary)
                    } else {
                        Text(String(format: "Every %.1f days", avgInterval / 86400))
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                HStack {
                    Text("New Photo Frequency")
                    Spacer()
                    Text("Not enough data")
                        .foregroundColor(.secondary)
                }
            }
            
            // Treatment Adherence Rate
            let adherencePercent = calculateAdherenceRate()
            HStack {
                Text("Treatment Adherence")
                Spacer()
                if adherencePercent >= 0 {
                    Text("\(adherencePercent)%")
                        .foregroundColor(.secondary)
                } else {
                    Text("Not enough data")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func calculateAdherenceRate() -> Int {
        var totalExpected = 0
        var totalActual = 0
        
        for (medication, frequency) in medicationSettings.frequencies {
            let medLogs = treatments.filter { $0.medicationName == medication }
            guard let firstLog = medLogs.min(by: { $0.timestamp < $1.timestamp }) else { continue }
            
            let daysElapsed = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: firstLog.timestamp), to: Calendar.current.startOfDay(for: Date())).day ?? 0
            
            totalExpected += max(1, (daysElapsed + 1)) * frequency
            totalActual += medLogs.count
        }
        
        if totalExpected == 0 {
            return -1 // No data or no frequencies set for active medications
        }
        
        return min(100, Int(Double(totalActual) / Double(totalExpected) * 100))
    }
}

struct TreatmentCalendarView: View {
    @Binding var calendarDate: Date
    @Binding var selectedTreatmentDate: Date?
    let treatments: [TreatmentLog]
    
    private var daysInMonth: [Date] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: calendarDate)
        guard let startOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: startOfMonth) else { return [] }
        
        return range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: startOfMonth)
        }
    }
    
    private var firstWeekday: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: calendarDate)
        guard let startOfMonth = calendar.date(from: components) else { return 1 }
        return calendar.component(.weekday, from: startOfMonth)
    }
    
    private func previousMonth() {
        if let newDate = Calendar.current.date(byAdding: .month, value: -1, to: calendarDate) {
            calendarDate = newDate
        }
    }
    
    private func nextMonth() {
        if let newDate = Calendar.current.date(byAdding: .month, value: 1, to: calendarDate) {
            calendarDate = newDate
        }
    }
    
    var body: some View {
        VStack {
            // Header
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .padding()
                }
                .buttonStyle(.borderless)
                
                Spacer()
                Text(calendarDate, format: .dateTime.month(.wide).year())
                    .font(.headline)
                Spacer()
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .padding()
                }
                .buttonStyle(.borderless)
            }
            
            // Grid
            let days = daysInMonth
            let leadingEmptyCells = firstWeekday - 1
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                // Weekday Headers
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day).font(.caption).bold().foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
                
                // Empty cells
                ForEach(0..<leadingEmptyCells, id: \.self) { _ in
                    Color.clear.frame(height: 60)
                }
                
                // Day cells
                ForEach(days, id: \.self) { date in
                    let dayTreatments = treatments.filter { Calendar.current.isDate($0.timestamp, inSameDayAs: date) }
                    let isToday = Calendar.current.isDateInToday(date)
                    
                    Button {
                        if !dayTreatments.isEmpty {
                            selectedTreatmentDate = date
                        }
                    } label: {
                        VStack(spacing: 2) {
                            Text("\(Calendar.current.component(.day, from: date))")
                                .font(.caption)
                                .fontWeight(isToday ? .bold : .regular)
                                .foregroundColor(isToday ? .white : .primary)
                                .padding(4)
                                .background(isToday ? Color.blue : Color.clear)
                                .clipShape(Circle())
                            
                            if !dayTreatments.isEmpty {
                                VStack(spacing: 2) {
                                    ForEach(dayTreatments.prefix(3)) { treatment in
                                        HStack(spacing: 2) {
                                            Image(systemName: "plus")
                                                .foregroundColor(colorForMedication(treatment.medicationName))
                                                .font(.system(size: 8, weight: .bold))
                                            if treatment.wasCleaned {
                                                Image(systemName: "drop.fill")
                                                    .foregroundColor(.blue)
                                                    .font(.system(size: 8))
                                            }
                                            if treatment.changedUndergarments {
                                                Image(systemName: "tshirt.fill")
                                                    .foregroundColor(.brown)
                                                    .font(.system(size: 8))
                                            }
                                        }
                                    }
                                    if dayTreatments.count > 3 {
                                        Text("...")
                                            .font(.system(size: 8))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .padding(.vertical, 4)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(dayTreatments.isEmpty)
                }
            }
            .padding(.horizontal, 4)
            
            // Legend
            VStack(alignment: .leading, spacing: 4) {
                Text("Medication Key").font(.caption).foregroundColor(.secondary).padding(.top, 8)
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").foregroundColor(.purple).font(.caption2)
                        Text("Terbinafine").font(.caption2)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "plus").foregroundColor(.orange).font(.caption2)
                        Text("Clotrimazole").font(.caption2)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "plus").foregroundColor(.mint).font(.caption2)
                        Text("Ketoconazole").font(.caption2)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "plus").foregroundColor(.pink).font(.caption2)
                        Text("Custom").font(.caption2)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        }
    }
}
