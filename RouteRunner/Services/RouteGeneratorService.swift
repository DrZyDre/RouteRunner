import Foundation
import MapKit
import CoreLocation

class RouteGeneratorService {
    
    // Generate multiple route options based on user preferences
    func generateRoutes(
        startLocation: CLLocationCoordinate2D,
        routeType: RouteType,
        targetDistance: Double, // in meters
        blacklistedAreas: [BlacklistedArea] = [],
        completion: @escaping ([Route]) -> Void
    ) {
        var routes: [Route] = []
        let group = DispatchGroup()
        
        switch routeType {
        case .loop:
            // Generate 5 loop variations
            for i in 0..<5 {
                group.enter()
                generateLoopRoute(
                    start: startLocation,
                    targetDistance: targetDistance,
                    variation: i,
                    blacklistedAreas: blacklistedAreas
                ) { route in
                    if let route = route {
                        routes.append(route)
                    }
                    group.leave()
                }
            }
            
        case .outAndBack:
            // Generate routes in different directions
            let directions: [Double] = [0, 60, 120, 180, 240, 300]
            for bearing in directions {
                group.enter()
                generateOutAndBackRoute(
                    start: startLocation,
                    targetDistance: targetDistance,
                    direction: bearing,
                    blacklistedAreas: blacklistedAreas
                ) { route in
                    if let route = route {
                        routes.append(route)
                    }
                    group.leave()
                }
            }
            
        case .straightOut:
            // Generate straight routes in different directions
            let directions: [Double] = [0, 60, 120, 180, 240, 300]
            for bearing in directions {
                group.enter()
                generateStraightRoute(
                    start: startLocation,
                    targetDistance: targetDistance,
                    direction: bearing,
                    blacklistedAreas: blacklistedAreas
                ) { route in
                    if let route = route {
                        routes.append(route)
                    }
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            routes.sort {
                abs($0.estimatedDistance - targetDistance) <
                abs($1.estimatedDistance - targetDistance)
            }
            completion(routes)
        }
    }
    
    // MARK: - Loop Route Generation
    
    private func generateLoopRoute(
        start: CLLocationCoordinate2D,
        targetDistance: Double,
        variation: Int,
        blacklistedAreas: [BlacklistedArea],
        completion: @escaping (Route?) -> Void
    ) {
        // Approximate a loop with 8 points in a circle
        let radius = targetDistance / (2 * .pi) * 0.9
        let angleOffset = Double(variation) * (2 * .pi / 5.0) // 5 variations
        
        var waypoints: [CLLocationCoordinate2D] = []
        let numPoints = 48
        
        for i in 0..<numPoints {
            let angle = (Double(i) / Double(numPoints)) * 2 * .pi + angleOffset
            let point = coordinateFrom(start: start, distance: radius, bearing: angle)
            waypoints.append(point)
        }
        
        // Close the loop by returning to start
        let loopWaypoints = [start] + waypoints + [start]
        
        buildRoute(
            routeType: .loop,
            waypoints: loopWaypoints,
            blacklistedAreas: blacklistedAreas,
            completion: completion
        )
    }
    
    // MARK: - Out and Back Route Generation
    
    private func generateOutAndBackRoute(
        start: CLLocationCoordinate2D,
        targetDistance: Double,
        direction: Double, // degrees, 0 = North
        blacklistedAreas: [BlacklistedArea],
        completion: @escaping (Route?) -> Void
    ) {
        let halfDistance = targetDistance / 2.0
        let bearingRadians = direction * .pi / 180.0
        
        let midpoint = coordinateFrom(
            start: start,
            distance: halfDistance,
            bearing: bearingRadians
        )
        
        // Start -> midpoint -> start
        let waypoints = [start, midpoint, start]
        
        buildRoute(
            routeType: .outAndBack,
            waypoints: waypoints,
            blacklistedAreas: blacklistedAreas,
            completion: completion
        )
    }
    
    // MARK: - Straight Route Generation
    
    private func generateStraightRoute(
        start: CLLocationCoordinate2D,
        targetDistance: Double,
        direction: Double,
        blacklistedAreas: [BlacklistedArea],
        completion: @escaping (Route?) -> Void
    ) {
        let bearingRadians = direction * .pi / 180.0
        
        let endpoint = coordinateFrom(
            start: start,
            distance: targetDistance,
            bearing: bearingRadians
        )
        
        let waypoints = [start, endpoint]
        
        buildRoute(
            routeType: .straightOut,
            waypoints: waypoints,
            blacklistedAreas: blacklistedAreas,
            completion: completion
        )
    }
    
    // MARK: - Shared Route Builder (multi-segment)
    
    /// Builds a route by chaining MKDirections for each consecutive waypoint pair
    private func buildRoute(
        routeType: RouteType,
        waypoints: [CLLocationCoordinate2D],
        blacklistedAreas: [BlacklistedArea],
        completion: @escaping (Route?) -> Void
    ) {
        guard waypoints.count >= 2 else {
            completion(nil)
            return
        }
        
        let segmentGroup = DispatchGroup()
        var totalDistance: Double = 0
        var totalTime: TimeInterval = 0
        var allCoordinates: [CLLocationCoordinate2D] = []
        var hadError = false
        
        for i in 0..<waypoints.count - 1 {
            segmentGroup.enter()
            
            let request = MKDirections.Request()
            request.transportType = .walking
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: waypoints[i]))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: waypoints[i + 1]))
            
            let directions = MKDirections(request: request)
            directions.calculate { response, error in
                defer { segmentGroup.leave() }
                
                guard let mkRoute = response?.routes.first, error == nil else {
                    hadError = true
                    return
                }
                
                if self.routePassesThroughBlacklisted(route: mkRoute, blacklistedAreas: blacklistedAreas) {
                    hadError = true
                    return
                }
                
                totalDistance += mkRoute.distance
                totalTime += mkRoute.expectedTravelTime
                
                let segmentCoords = self.coordinates(from: mkRoute.polyline)
                allCoordinates.append(contentsOf: segmentCoords)
            }
        }
        
        segmentGroup.notify(queue: .main) {
            guard !hadError, !allCoordinates.isEmpty else {
                completion(nil)
                return
            }
            
            let routeModel = Route(
                startLocation: waypoints[0],
                routeType: routeType,
                targetDistance: totalDistance,
                waypoints: waypoints,
                polylineCoordinates: allCoordinates,
                estimatedDistance: totalDistance,
                estimatedTime: totalTime
            )
            
            completion(routeModel)
        }
    }
    
    // MARK: - Helper Functions
    
    // Calculate a coordinate at a distance and bearing from a start point
    private func coordinateFrom(
        start: CLLocationCoordinate2D,
        distance: Double,
        bearing: Double
    ) -> CLLocationCoordinate2D {
        let earthRadius: Double = 6371000 // meters
        
        let lat1 = start.latitude * .pi / 180
        let lon1 = start.longitude * .pi / 180
        
        let lat2 = asin(
            sin(lat1) * cos(distance / earthRadius) +
            cos(lat1) * sin(distance / earthRadius) * cos(bearing)
        )
        
        let lon2 = lon1 + atan2(
            sin(bearing) * sin(distance / earthRadius) * cos(lat1),
            cos(distance / earthRadius) - sin(lat1) * sin(lat2)
        )
        
        return CLLocationCoordinate2D(
            latitude: lat2 * 180 / .pi,
            longitude: lon2 * 180 / .pi
        )
    }
    
    // Extract coordinates from an MKPolyline
    private func coordinates(from polyline: MKPolyline) -> [CLLocationCoordinate2D] {
        let count = polyline.pointCount
        guard count > 0 else { return [] }
        
        let buffer = UnsafeMutablePointer<CLLocationCoordinate2D>.allocate(capacity: count)
        polyline.getCoordinates(buffer, range: NSRange(location: 0, length: count))
        
        var coords: [CLLocationCoordinate2D] = []
        coords.reserveCapacity(count)
        for i in 0..<count {
            coords.append(buffer[i])
        }
        
        buffer.deallocate()
        return coords
    }
    
    // Stub: always returns false for now (no blacklist logic yet)
    private func routePassesThroughBlacklisted(
        route: MKRoute,
        blacklistedAreas: [BlacklistedArea]
    ) -> Bool {
        // TODO: implement polygon intersection if needed
        return false
    }
    
    //Returns true if the route ends in a "dead-end"-like tail.
    //Heuristic: the last X% of the route ends very close to an earlier point.
    private func routeHasDeadEndTail(_ polyline: MKPolyline) -> Bool {
        let count = polyline.pointCount
        guard count > 10 else { return false } //too short to analyze
        
        //Get coordinates
        let buffer = UnsafeMutablePointer<CLLocationCoordinate2D>.allocate(capacity: count)
        polyline.getCoordinates(buffer, range: NSRange(location: 0, length: count))
        defer { buffer.deallocate() }
        
        //Look at the last 20% of points
        let endIndex = count - 1
        let tailStartIndex = max(0, Int(Double(count) * 0.8))
        
        let endCoord = buffer[endIndex]
        
        //Find the closest point in hte earlier part of the route
        var minDistance: CLLocationDistance = .greatestFiniteMagnitude
        for i in 0..<tailStartIndex {
            let c = buffer[i]
            let d = distanceBetween(c, endCoord)
            if d < minDistance {
                minDistance = d
            }
        }
        
        //If the end of the route is very close to an earlier part of the route,
        //but the tail itself (last 20%) is reasonably long, it looks like a cul-de-sac.
        let tailDistance = polylineLength(from: buffer, startIndex: tailStartIndex, endIndex: endIndex)
        
        let closeThreshold: CLLocationDistance = 50 //Meters
        let tailMinDistance: CLLocationDistance = 200 //Meters
        
        return minDistance < closeThreshold && tailDistance > tailMinDistance
    }
    
    //Haversine distance between two coordinates
    private func distanceBetween(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> CLLocationDistance {
        let locA = CLLocation(latitude: a.latitude, longitude: a.longitude)
        let locB = CLLocation(latitude: b.latitude, longitude: b.longitude)
        return locA.distance(from: locB)
    }
    
    //Approximate length of part of a polyline
    private func polylineLength(
        from coords: UnsafePointer<CLLocationCoordinate2D>,
        startIndex: Int,
        endIndex: Int,
    ) -> CLLocationDistance {
        guard endIndex > startIndex else { return 0 }
        var total: CLLocationDistance = 0
        for i in startIndex..<endIndex {
            total += distanceBetween(coords[i], coords[i + 1])
        }
        return total
    }
}
