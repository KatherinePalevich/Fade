//
//  ContentView.swift
//  Fade
//
//  Created by Katherine Palevich on 4/15/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            BodyMapView()
                .tabItem {
                    Label("Rash Tracker", systemImage: "figure.walk")
                }
                .tag(0)
            
            TreatmentFormView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Treatment", systemImage: "cross.case.fill")
                }
                .tag(1)
            
            SummaryView()
                .tabItem {
                    Label("Summary", systemImage: "chart.xyaxis.line")
                }
                .tag(2)
        }
    }
}

