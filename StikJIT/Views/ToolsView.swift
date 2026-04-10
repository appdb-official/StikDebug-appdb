//
//  ToolsView.swift
//  StikJIT
//
//  Created by Stephen on 2/23/26.
//

import SwiftUI

struct ToolsView: View {
    private struct ToolItem: Identifiable {
        let id: String
        let title: String
        let detail: String
        let systemImage: String
        let destination: AnyView
    }

    private var tools: [ToolItem] {
        [
            ToolItem(id: "scripts", title: "Scripts", detail: "Manage and run JS scripts", systemImage: "scroll", destination: AnyView(ScriptListView())),
            ToolItem(id: "console", title: "Console", detail: "Live device logs", systemImage: "terminal", destination: AnyView(ConsoleLogsView())),
            ToolItem(id: "deviceinfo", title: "Device Info", detail: "View detailed device metadata", systemImage: "iphone.and.arrow.forward", destination: AnyView(DeviceInfoView())),
            ToolItem(id: "profiles", title: "App Expiry", detail: "Check app expiration dates", systemImage: "calendar.badge.clock", destination: AnyView(ProfileView())),
            ToolItem(id: "processes", title: "Processes", detail: "Inspect running apps", systemImage: "rectangle.stack.person.crop", destination: AnyView(ProcessInspectorView())),
            ToolItem(id: "location", title: "Location Simulation", detail: "Simulate GPS location", systemImage: "location", destination: AnyView(LocationSimulationView()))
        ]
    }

    var body: some View {
        NavigationStack {
            List(tools) { tool in
                NavigationLink {
                    tool.destination
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tool.title)
                            Text(tool.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: tool.systemImage)
                    }
                }
            }
            .navigationTitle("Tools")
        }
    }
}
