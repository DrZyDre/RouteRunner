import Foundation
import MapKit

//Represents an area the user wants to avoid
struct BlacklistedArea: Identifiable, Codable {
    let id: UUID
    let name: String
    let coordinates:[CLLocationCoordinate2D] //Polygon points

    enum CodingKeys: String, CodingKey {
        case id, name
        case coordinateLatitudes, coordinateLongitudes
    }
    
    init(id: UUID = UUID(), name: String, coordinates: [CLLocationCoordinate2D]) {
        self.id = id
        self.name = name
        self.coordinates = coordinates
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(coordinates.map { $0.latitude }, forKey: .coordinateLatitudes)
        try container.encode(coordinates.map { $0.longitude }, forKey: .coordinateLongitudes)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        let lats = try container.decode([Double].self, forKey: .coordinateLatitudes)
        let lons = try container.decode([Double].self, forKey: .coordinateLongitudes)
        coordinates = zip(lons, lats).map { CLLocationCoordinate2D(latitude: $0, longitude: $1) }
    }
    
}
