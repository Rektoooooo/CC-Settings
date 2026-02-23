import Foundation

struct LocalSettings: Codable, Equatable {
    var permissions: PermissionsConfig = PermissionsConfig()
}
