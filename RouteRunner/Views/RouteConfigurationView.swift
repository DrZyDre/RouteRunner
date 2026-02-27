import SwiftUI
import CoreLocation

struct RouteConfigurationView: View {
    @ObservedObject var locationManager: LocationManager
    @Environment(\.dismiss) var dismiss

    @State private var selectedRouteType: RouteType = .loop
    @State private var distance: Double = 5000 //meters (5k default)
    @State private var isGenerating = false

    let onRoutesGenerated: ([Route]) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Route Type")) {
                    Picker("Type", selection: $selectedRouteType) {
                        ForEach(RouteType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }

                Section(header: Text("Distance")) {
                    VStack {
                        Slider(value: $distance, in: 1000...20000, step: 500)
                        Text("\(Int(distance / 1000)) km")
                            .font(.headline)
                    }
                }

                Section {
                    Button(action: generateRoutes) {
                        HStack {
                            if isGenerating {
                                ProgressView()
                            }
                            Text(isGenerating ? "Generating Routes..." : "Generate Routes")
                        }
                    }
                    .disabled(isGenerating || locationManager.currentLocation == nil)
                }
            }
            .navigationTitle("New Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func generateRoutes() {
        guard let startLocation = locationManager.currentLocation?.coordinate else {
            return
        }

        isGenerating = true

        let generator = RouteGeneratorService()
        generator.generateRoutes(
            startLocation: startLocation,
            routeType: selectedRouteType,
            targetDistance: distance,
            blacklistedAreas: []
        ) { routes in
            print("Generated \(routes.count) routes")
            isGenerating = false
            
            if let best = routes.first {
                onRoutesGenerated([best])
            } else {
                onRoutesGenerated([])
            }
//            for r in routes {
//                print("Route type: \(r.routeType), distance: \(r.estimatedDistance)")
//            }
//            isGenerating = false
//            onRoutesGenerated(routes)
            dismiss()
        }
    }
}
