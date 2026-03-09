import SwiftUI

struct LanguagePickerView: View {
    let regions: [String]
    let onTranslate: ([String]) -> Void
    let onCancel: () -> Void

    @State private var selectedRegions: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "selectLanguages"))
                .font(.headline)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(regions, id: \.self) { region in
                        Toggle(isOn: binding(for: region)) {
                            Text(displayName(for: region))
                        }
                        .toggleStyle(.checkbox)
                    }
                }
            }
            .frame(maxHeight: 200)

            Divider()

            HStack {
                Button(String(localized: "selectAll")) {
                    selectedRegions = Set(regions)
                }
                .buttonStyle(.link)

                Button(String(localized: "deselectAll")) {
                    selectedRegions = []
                }
                .buttonStyle(.link)

                Spacer()

                Button(String(localized: "cancel")) {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button(String(localized: "translate")) {
                    onTranslate(Array(selectedRegions))
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedRegions.isEmpty)
            }
        }
        .padding()
        .frame(width: 250)
        .onAppear {
            selectedRegions = Set(regions)
        }
    }

    private func binding(for region: String) -> Binding<Bool> {
        Binding(
            get: { selectedRegions.contains(region) },
            set: { isOn in
                if isOn {
                    selectedRegions.insert(region)
                } else {
                    selectedRegions.remove(region)
                }
            }
        )
    }

    private func displayName(for regionCode: String) -> String {
        let locale = Locale.current
        let name = locale.localizedString(forIdentifier: regionCode)
        if let name {
            return "\(name) (\(regionCode))"
        }
        return regionCode
    }
}
