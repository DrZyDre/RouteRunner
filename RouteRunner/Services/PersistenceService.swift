import Foundation

class PersistenceService {
    private let routesKey = "saved_routes"
    private let blacklistKey = "blacklisted_areas"

    //Save routes to UserDefaults
    func saveRoute(_ route: Route) {
        var savedRoutes = loadRoutes()
        savedRoutes.append(route)

        if let encoded = try? JSONEncoder().encode(savedRoutes) {
            UserDefaults.standard.set(encoded, forKey: routesKey)
        }
    }

    //load all saved routes
    func loadRoutes() -> [Route] {
        guard let data = UserDefaults.standard.data(forKey: routesKey),
              let routes = try? JSONDecoder().decode([Route].self, from: data) else {
            return []
        }
        return routes
    }

    //Delete a route
    func deleteRoute(_ route: Route) {
        var savedRoutes = loadRoutes()
        savedRoutes.removeAll { $0.id == route.id }

        if let encoded = try? JSONEncoder().encode(savedRoutes) {
            UserDefaults.standard.set(encoded, forKey: routesKey)
        }
    }
}