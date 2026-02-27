import SwiftUI
import MapKit

struct MainMapView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var selectedRoute: Route?
    @State private var showingRouteConfig = false
    @State private var routes: [Route] = []
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // Default SF
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    var body: some View {
        ZStack {
            // Map view
            MapViewWithRoutes(
                region: $region,
                routes: routes,
                showsUserLocation: true
            )
            .onAppear {
                locationManager.requestPermission()
            }
            .onChange(of: locationManager.currentLocation) { location in
                if let location = location {
                    region.center = location.coordinate
                }
            }
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        showingRouteConfig = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingRouteConfig) {
            RouteConfigurationView(
                locationManager: locationManager,
                onRoutesGenerated: { newRoutes in
                    routes = newRoutes
                }
            )
        }
    }
}

//Wrapper around MKMapView so we can draw route polylines
struct MapViewWithRoutes: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var routes: [Route]
    var showsUserLocation: Bool
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = showsUserLocation
        mapView.setRegion(region, animated: false)
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.setRegion(region, animated: true)
        
        //Remove existing route overlays and re-add for current routes
        let existingOverlays = mapView.overlays.filter { $0 is MKPolyline }
        mapView.removeOverlays(existingOverlays)
        
        for route in routes where !route.polylineCoordinates.isEmpty {
            let polyline = MKPolyline(coordinates: route.polylineCoordinates, count: route.polylineCoordinates.count)
            mapView.addOverlay(polyline)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 4
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
