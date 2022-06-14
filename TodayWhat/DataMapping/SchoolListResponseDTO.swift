import Foundation

struct SchoolListResponseDTO: Decodable {
    let orgCode: String
    let schoolCode: String
    let schoolName: String
    let schoolKind: SchoolKind
    
    enum CodingKeys: String, CodingKey {
        case orgCode = "ATPT_OFCDC_SC_CODE"
        case schoolCode = "SD_SCHUL_CODE"
        case schoolName = "SCHUL_NM"
        case schoolKind = "SCHUL_KND_SC_NM"
    }
}

extension SchoolListResponseDTO {
    func toDomain() -> School {
        return .init(
            orgCode: orgCode,
            schoolCode: schoolCode,
            schoolName: schoolName,
            schoolType: schoolKind.toType()
        )
    }
}
