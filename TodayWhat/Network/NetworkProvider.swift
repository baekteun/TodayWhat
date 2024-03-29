import Foundation
import Combine
import SwiftyJSON

protocol NetworkProviderProtocol {
    func fetchMealList() -> AnyPublisher<Meal, Never>
    func searchSchool(name: String) -> AnyPublisher<School, TodayWhatError>
    func fetchTimeTable() -> AnyPublisher<[TimeTable], Never>
}

public struct NetworkProvider: NetworkProviderProtocol {
    private let neisBaseURL = "https://open.neis.go.kr/hub/"
    
    static let shared = NetworkProvider()
    private let decoder = JSONDecoder()
    
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func fetchMealList() -> AnyPublisher<Meal, Never> {
        guard
            let orgCode = UserDefaultsLocal.shared.orgCode,
            let code = UserDefaultsLocal.shared.code
        else {
            return Just(Meal(breakfast: [], lunch: [], dinner: [])).eraseToAnyPublisher()
        }
        guard var urlComponents = URLComponents(string: neisBaseURL + "mealServiceDietInfo") else { return Just(Meal(breakfast: [], lunch: [], dinner: [])).eraseToAnyPublisher() }
        var today = Date()
        if UserDefaultsLocal.shared.skipWeekend {
            skipWeekend(date: &today)
        }
        print(today)
        let month = today.month < 10 ? "0\(today.month)" : "\(today.month)"
        let day = today.day < 10 ? "0\(today.day)" : "\(today.day)"
        let date = "\(today.year)\(month)\(day)"
        urlComponents.queryItems = []
        urlComponents.queryItems?.append(contentsOf: [
            .init(name: "KEY", value: ""),
            .init(name: "Type", value: "json"),
            .init(name: "pIndex", value: "1"),
            .init(name: "pSize", value: "30"),
            .init(name: "ATPT_OFCDC_SC_CODE", value: orgCode),
            .init(name: "SD_SCHUL_CODE", value: code),
            .init(name: "MLSV_FROM_YMD", value: date),
            .init(name: "MLSV_TO_YMD", value: date)
        ])
        guard let url = urlComponents.url else { return Just(Meal(breakfast: [], lunch: [], dinner: [])).eraseToAnyPublisher() }
        return session.dataTaskPublisher(for: url)
            .map(\.data)
            .tryMap { data in
                let json = try JSON(data: data)
                guard let _ = json["RESULT"].null else {
                    throw TodayWhatError.fetchFailed
                }
                var info = json["mealServiceDietInfo"].arrayValue
                _ = info.removeFirst()
                if let json = try info.first?["row"].rawData() {
                    return json
                }
                throw TodayWhatError.fetchFailed
            }
            .decode(type: [mealInfoResponseDTO].self, decoder: decoder)
            .catch { _ in Just([]) }
            .map({ dto in
                let dto = Array(dto.reversed())
                let breakfast = dto.first(where: { $0.mealType == .breakfast } )?.info.replacingOccurrences(of: " ", with: "").components(separatedBy: "<br/>") ?? []
                let lunch = dto.first(where: { $0.mealType == .lunch } )?.info.replacingOccurrences(of: " ", with: "").components(separatedBy: "<br/>") ?? []
                let dinner = dto.first(where: { $0.mealType == .dinner } )?.info.replacingOccurrences(of: " ", with: "").components(separatedBy: "<br/>") ?? []
                return Meal(breakfast: breakfast, lunch: lunch, dinner: dinner)
            })
            .eraseToAnyPublisher()
    }
    
    func searchSchool(name: String) -> AnyPublisher<School, TodayWhatError> {
        guard var urlComponents = URLComponents(string: neisBaseURL + "schoolInfo") else { return Fail(error: TodayWhatError.fetchFailed).eraseToAnyPublisher() }
        urlComponents.queryItems = []
        urlComponents.queryItems?.append(contentsOf: [
            .init(name: "KEY", value: ""),
            .init(name: "Type", value: "json"),
            .init(name: "pIndex", value: "1"),
            .init(name: "pSize", value: "3"),
            .init(name: "SCHUL_NM", value: name)
        ])
        guard let url = urlComponents.url else { return Fail(error: TodayWhatError.fetchFailed).eraseToAnyPublisher() }
        return session.dataTaskPublisher(for: url)
            .map(\.data)
            .tryMap { data in
                let json = try JSON(data: data)
                guard let _ = json["RESULT"].null else {
                    throw TodayWhatError.fetchFailed
                }
                var info = json["schoolInfo"].arrayValue
                _ = info.removeFirst()
                if let json = try info.first?["row"].rawData() {
                    return json
                }
                throw TodayWhatError.fetchFailed
            }
            .decode(type: [SchoolListResponseDTO].self, decoder: decoder)
            .map { $0.map { $0.toDomain() } }
            .tryMap({ schools -> School in
                if let school = schools.first {
                    return school
                }
                throw TodayWhatError.fetchFailed
            })
            .mapError { _ in TodayWhatError.fetchFailed }
            .eraseToAnyPublisher()
    }
    
    func fetchTimeTable() -> AnyPublisher<[TimeTable], Never> {
        guard
            let type = UserDefaultsLocal.shared.schoolType,
            let code = UserDefaultsLocal.shared.code,
            let orgCode = UserDefaultsLocal.shared.orgCode
        else {
            return Just([]).eraseToAnyPublisher()
        }
        var today = Date()
        if UserDefaultsLocal.shared.skipWeekend {
            skipWeekend(date: &today)
        }
        let month = today.month < 10 ? "0\(today.month)" : "\(today.month)"
        let day = today.day < 10 ? "0\(today.day)" : "\(today.day)"
        let date = "\(today.year)\(month)\(day)"
        guard var urlComponents = URLComponents(string: neisBaseURL + type.toSubURL()) else { return Just([]).eraseToAnyPublisher() }
        urlComponents.queryItems = []
        urlComponents.queryItems?.append(contentsOf: [
            .init(name: "KEY", value: ""),
            .init(name: "Type", value: "json"),
            .init(name: "pIndex", value: "1"),
            .init(name: "pSize", value: "30"),
            .init(name: "ATPT_OFCDC_SC_CODE", value: orgCode),
            .init(name: "SD_SCHUL_CODE", value: code),
            .init(name: "DDDEP_NM", value: UserDefaultsLocal.shared.schoolDept),
            .init(name: "GRADE", value: "\(UserDefaultsLocal.shared.grade)"),
            .init(name: "CLASS_NM", value: "\(UserDefaultsLocal.shared.class)"),
            .init(name: "TI_FROM_YMD", value: date),
            .init(name: "TI_TO_YMD", value: date)
        ])
        guard let url = urlComponents.url else { return Just([]).eraseToAnyPublisher() }
        return session.dataTaskPublisher(for: url)
            .map(\.data)
            .tryMap { data in
                let json = try JSON(data: data)
                guard let _ = json["RESULT"].null else {
                    throw TodayWhatError.fetchFailed
                }
                var info = json["\(type.toSubURL())"].arrayValue
                _ = info.removeFirst()
                if let json = try info.first?["row"].rawData() {
                    return json
                }
                throw TodayWhatError.fetchFailed
            }
            .decode(type: [TimeTableResponseDTO].self, decoder: decoder)
            .catch { _ in Just([]) }
            .map { $0.map { $0.toDomain() } }
            .eraseToAnyPublisher()
    }
}

private extension NetworkProvider {
    func skipWeekend(date: inout Date) {
        if date.weekday == "Sat" {
            date = date.addingTimeInterval(86400 * 2)
        } else if date.weekday == "Sun" {
            date = date.addingTimeInterval(86400)
        }
    }
}
