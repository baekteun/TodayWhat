import Foundation

struct mealInfoResponseDTO: Decodable {
    let info: String
    let mealType: MealType
    
    enum CodingKeys: String, CodingKey {
        case info = "DDISH_NM"
        case mealType = "MMEAL_SC_NM"
    }
}
