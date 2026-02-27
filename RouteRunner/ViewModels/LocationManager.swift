import Foundation
import CoreLocation
import Combine

//ObservableObject allows SwiftUI views to react to changes
class LocationManager: NSObject, ObservableObject {
    //Published properties automatically update UI when changed
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var locationError: String?

    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        //Set this class as the delegate to receive location updates
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        //For running, we want high accuracy
    }

    //Request permission to use location
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    //Start tracking location
    func startLocationUpdates() {
        guard authorizationStatus == .authorizedWhenInUse ||
              authorizationStatus == .authorizedAlways else {
            requestPermission()
            return
        }
        locationManager.startUpdatingLocation()
    }

    //Stop tracking (saves battery)
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
    }
}

//CLLocationManagerDelegate methods - called by the system
extension LocationManager: CLLocationManagerDelegate {
    //Called when user grants/denies permission
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        case .denied, .restricted:
            locationError = "Location access denied. Please enable in Settings."
        case .notDetermined:
            requestPermission()
        @unknown default:
            break
        }
    }

    //Called when new location data is available
    func locationManager(_ manager: CLLocationManager,
                        didUpdateLocations locations: [CLLocation]) {
        //Get the most recent location
        guard let location = locations.last else { return }
        currentLocation = location
    }

    //Called if location services fail
    func locationManager(_ manager: CLLocationManager,
                        didFailWithError error: Error) {
        locationError = error.localizedDescription
    }
}