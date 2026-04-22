import SwiftUI
import SwiftData
import Charts

struct SummaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RashEntry.timestamp) private var entries: [RashEntry]
    @Query(sort: \TreatmentLog.timestamp) private var treatments: [TreatmentLog]
    @Query private var sites: [RashSite]
    
    enum RashFilterState: String, CaseIterable, Identifiable {
        case active = "Active"
        case healed = "Healed"
        var id: String { self.rawValue }
    }
    
    @State private var filterState: RashFilterState = .active
    @State private var showingResetAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    if entries.isEmpty {
                        Text("No data to show.")
                            .padding()
                    } else {
                        VStack {
                            Chart {
                                let aggregated = aggregateEntriesByDay(entries: entries)
                                
                                ForEach(aggregated.sorted(by: { $0.key < $1.key }), id: \.key) { date, area in
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
                                .padding(.bottom)
                        }
                    }
                }
                
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
}
