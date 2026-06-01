//
//  ContentView.swift
//  Fade
//
//  Created by Katherine Palevich on 4/15/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 2
    @State private var activeTreatmentContext: TreatmentLog?
    @State private var isEditMode = false
    @State private var editingTreatmentLog: TreatmentLog?
    @StateObject private var notificationManager = NotificationManager.shared
    @Environment(\.scenePhase) var scenePhase
    
    var body: some View {
        TabView(selection: $selectedTab) {
            BodyMapView(activeTreatmentContext: $activeTreatmentContext, isEditMode: $isEditMode)
                .tabItem {
                    Label("Rash Tracker", systemImage: "figure.walk")
                }
                .tag(0)
            
            TreatmentFormView(selectedTab: $selectedTab, activeTreatmentContext: $activeTreatmentContext, isEditMode: $isEditMode, editingTreatmentLog: $editingTreatmentLog)
                .tabItem {
                    Label("Treatment", systemImage: "cross.case.fill")
                }
                .tag(1)
            
            SummaryView(selectedTab: $selectedTab, editingTreatmentLog: $editingTreatmentLog)
                .tabItem {
                    Label("Summary", systemImage: "chart.xyaxis.line")
                }
                .tag(2)
        }
        .onChange(of: selectedTab) { newTab in
            if newTab != 1 {
                editingTreatmentLog = nil
            }
        }
        .onChange(of: notificationManager.selectedTabFromNotification) { newValue in
            if let newTab = newValue {
                selectedTab = newTab
                notificationManager.selectedTabFromNotification = nil
            }
        }
        .blur(radius: scenePhase != .active ? 15 : 0)
    }
}

