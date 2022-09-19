import Foundation

final class UserDefaultsLocal {
    static let shared = UserDefaultsLocal()
    
    private let preferences: UserDefaults
    
    init(userDefaults: UserDefaults = .standard) {
        self.preferences = userDefaults
    }
    
    var schoolType: SchoolType? {
        get { SchoolType(rawValue: preferences.string(forKey: Consts.schoolType) ?? "") }
        set { preferences.setValue(newValue?.rawValue ?? "", forKey: Consts.schoolType) }
    }
    var orgCode: String? {
        get { preferences.string(forKey: Consts.orgCode) }
        set { preferences.setValue(newValue, forKey: Consts.orgCode) }
    }
    var code: String? {
        get { preferences.string(forKey: Consts.schoolCode) }
        set { preferences.setValue(newValue, forKey: Consts.schoolCode) }
    }
    var school: String? {
        get { preferences.string(forKey: Consts.schoolName) }
        set { preferences.setValue(newValue, forKey: Consts.schoolName) }
    }
    var grade: Int {
        get { preferences.integer(forKey: Consts.grade) }
        set { preferences.setValue(newValue, forKey: Consts.grade) }
    }
    var `class`: Int {
        get { preferences.integer(forKey: Consts.class) }
        set { preferences.setValue(newValue, forKey: Consts.class) }
    }
    var schoolDept: String? {
        get { preferences.string(forKey: Consts.schoolDept) }
        set { preferences.setValue(newValue, forKey: Consts.schoolDept) }
    }
    var skipWeekend: Bool {
        get { preferences.bool(forKey: Consts.skipWeekend) }
        set { preferences.setValue(newValue, forKey: Consts.skipWeekend) }
    }
}
