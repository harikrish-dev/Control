import Foundation

struct Room: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var icon: String

    init(id: UUID = UUID(), name: String, icon: String = "house.fill") {
        self.id = id
        self.name = name
        self.icon = icon
    }
}
