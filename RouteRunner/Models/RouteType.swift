import Foundation

//Enum defines the three types of runs users can choose
enum RouteType: String, CaseIterable, Codable {
    case loop = "Loop" //Circular route that returns to start
    case outAndBack = "Out and Back" //Go to a poin, then return same path
    case straightOut = "Straight Out" //One-way route in a direction

    //CaseIterable lets us easily loop through all option in UI
}