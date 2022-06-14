import Foundation

struct TimeTableResponseDTO: Decodable {
    let perio: String
    let content: String
    
    enum CodingKeys: String, CodingKey {
        case perio = "PERIO"
        case content = "ITRT_CNTNT"
    }
}

extension TimeTableResponseDTO {
    func toDomain() -> TimeTable {
        return .init(
            perio: Int(perio) ?? 1,
            content: content
        )
    }
}
