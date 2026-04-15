import SwiftUI
import SwiftData
import Charts

struct SummaryView: View {
    @Query(sort: \RashEntry.timestamp) private var entries: [RashEntry]
    @Query(sort: \TreatmentLog.timestamp) private var treatments: [TreatmentLog]
    
    var body: some View {
        NavigationStack {
            VStack {
                if entries.isEmpty {
                    Text("No data to show.")
                } else {
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
                    .padding()
                    
                    Text("Healing Progress vs Treatments")
                        .font(.headline)
                        .padding()
                }
                Spacer()
            }
            .navigationTitle("Summary")
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
