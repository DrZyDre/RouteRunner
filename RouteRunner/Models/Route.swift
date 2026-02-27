import Foundation
import MapKit

//Identifiable allow this to work with SwiftUI Lists/ForEach
//Codable allows saving/loading from storage
struct Route: Identifiable, Codable {
    let id: UUID
    let startLocation: CLLocationCoordinate2D
    let routeType: RouteType
    let targetDistance: Double //in meters
    let waypoints: [CLLocationCoordinate2D] //Key points along the route
    let polylineCoordinates: [CLLocationCoordinate2D] //Coordinates along the actual road path
    let estimatedDistance: Double //Actual calculated distance
    let estimatedTime: TimeInterval //Estimated running time (seconds)
    let name: String? //Optional name if user saves it

    //Custom Codable because CLLocationCoordinate2D isn't Codable by default
    enum CodingKeys: String, CodingKey {
        case id, routeType, targetDistance, estimatedDistance, estimatedTime, name
        case startLatitude, startLongitude
        case waypointLatitudes, waypointLongitudes
        case polylineLatitudes, polylineLongitudes
    }

    init(id: UUID = UUID(),
         startLocation: CLLocationCoordinate2D,
         routeType: RouteType,
         targetDistance: Double,
         waypoints: [CLLocationCoordinate2D],
         polylineCoordinates: [CLLocationCoordinate2D] = [],
         estimatedDistance: Double,
         estimatedTime: TimeInterval,
         name: String? = nil) {
            self.id = id
            self.startLocation = startLocation
            self.routeType = routeType
            self.targetDistance = targetDistance
            self.waypoints = waypoints
            self.polylineCoordinates = polylineCoordinates
            self.estimatedDistance = estimatedDistance
            self.estimatedTime = estimatedTime
            self.name = name
    }
    
    //Custom encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(routeType, forKey: .routeType)
        try container.encode(targetDistance, forKey: .targetDistance)
        try container.encode(estimatedDistance, forKey: .estimatedDistance)
        try container.encode(estimatedTime, forKey: .estimatedTime)
        try container.encode(name, forKey: .name)
        try container.encode(startLocation.latitude, forKey: .startLatitude)
        try container.encode(startLocation.longitude, forKey: .startLongitude)
        try container.encode(waypoints.map { $0.latitude }, forKey: .waypointLatitudes)
        try container.encode(waypoints.map { $0.longitude }, forKey: .waypointLongitudes)
        try container.encode(polylineCoordinates.map { $0.latitude }, forKey: .polylineLatitudes)
        try container.encode(polylineCoordinates.map { $0.longitude }, forKey: .polylineLongitudes)
    }

    //Custom decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        routeType = try container.decode(RouteType.self, forKey: .routeType)
        targetDistance = try container.decode(Double.self, forKey: .targetDistance)
        estimatedDistance = try container.decode(Double.self, forKey: .estimatedDistance)
        estimatedTime = try container.decode(TimeInterval.self, forKey: .estimatedTime)
        name = try container.decodeIfPresent(String.self, forKey: .name)

        let startLat = try container.decode(Double.self, forKey: .startLatitude)
        let startLon = try container.decode(Double.self, forKey: .startLongitude)
        startLocation = CLLocationCoordinate2D(latitude: startLat, longitude: startLon)

        let waypointLats = try container.decode([Double].self, forKey: .waypointLatitudes)
        let waypointLons = try container.decode([Double].self, forKey: .waypointLongitudes)
        waypoints = zip(waypointLats, waypointLons).map {
            CLLocationCoordinate2D(latitude: $0, longitude: $1)
        }
        
        let polylineLats = try container.decodeIfPresent([Double].self, forKey: .polylineLatitudes) ?? []
        let polylineLons = try container.decodeIfPresent([Double].self, forKey: .polylineLongitudes) ?? []
        polylineCoordinates = zip(polylineLats, polylineLons).map {
            CLLocationCoordinate2D(latitude: $0, longitude: $1)
        }
    }

}
