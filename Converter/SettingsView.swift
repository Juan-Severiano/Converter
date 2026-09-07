//
//  SettingsView.swift
//  Converter
//
//  The architecture the spec asks for (Output location / Overwrite / Keep original / Default
//  quality) — only "same folder" + "always keep original" + default quality actually drive
//  behavior in this version; the rest is wired to persisted state and visibly marked as
//  not-yet-active rather than silently ignored.
//

import ConvertCore
import SwiftUI

struct SettingsView: View {
    private static let defaults = UserDefaults.standard

    @AppStorage("outputLocation", store: SettingsView.defaults)
    private var outputLocationRaw: String = OutputLocation.sameFolder.rawValue

    @AppStorage("askBeforeReplacing", store: SettingsView.defaults)
    private var askBeforeReplacing = false

    @AppStorage("alwaysKeepOriginal", store: SettingsView.defaults)
    private var alwaysKeepOriginal = true

    @AppStorage("defaultQuality", store: SettingsView.defaults)
    private var defaultQuality = 85

    private enum OutputLocation: String, CaseIterable {
        case sameFolder, askEveryTime, customFolder

        var title: String {
            switch self {
            case .sameFolder: "Same folder as original"
            case .askEveryTime: "Ask every time"
            case .customFolder: "Custom folder"
            }
        }
    }

    var body: some View {
        Form {
            Section("Output location") {
                Picker("Output location", selection: $outputLocationRaw) {
                    ForEach(OutputLocation.allCases, id: \.rawValue) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()

                if outputLocationRaw != OutputLocation.sameFolder.rawValue {
                    notYetActiveNote("Convert always saves next to the original file for now.")
                }
            }

            Section("Overwrite existing files") {
                Toggle("Ask before replacing", isOn: $askBeforeReplacing)
                notYetActiveNote("Convert always adds “(1)”, “(2)”, etc. instead of replacing a file.")
            }

            Section("Keep original") {
                Toggle("Always keep original", isOn: $alwaysKeepOriginal)
                    .disabled(true)
            }

            Section("Default image quality") {
                HStack {
                    Slider(value: Binding(get: { Double(defaultQuality) }, set: { defaultQuality = Int($0) }), in: 1...100, step: 1)
                    Text("\(defaultQuality)%")
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 380)
    }

    private func notYetActiveNote(_ text: String) -> some View {
        Text("Coming in a future version — \(text)")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
