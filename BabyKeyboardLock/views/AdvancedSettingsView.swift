//
//  AdvancedSettingsView.swift
//  BabyKeyboardLock
//
//  Native macOS Settings window
//

import SwiftUI

struct AdvancedSettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            Text("More settings coming soon")
                .tabItem {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                }
        }
        .frame(width: 500, height: 400)
    }
}

struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Section {
                Text("Settings placeholder")
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }
}

#Preview {
    AdvancedSettingsView()
}
