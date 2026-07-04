import Foundation

struct SessionEntry: Codable, Identifiable {
    let id: Int
    let time: String
    let mousePoints: [Int]
    let mousePixels: [Int]
    let screenshot: String
    let crop: String
    let note: String

    enum CodingKeys: String, CodingKey {
        case id = "index"
        case time
        case mousePoints = "mouse_points"
        case mousePixels = "mouse_pixels"
        case screenshot
        case crop
        case note
    }
}

struct PendingCapture {
    let index: Int
    let time: String
    let mousePoints: [Int]
    let mousePixels: [Int]
    let screenshot: String
    let crop: String
}
