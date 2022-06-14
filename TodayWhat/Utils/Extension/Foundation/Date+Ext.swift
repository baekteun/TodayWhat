import Foundation

extension Date {
    var currentCal: Calendar {
        .current
    }
    var year: Int {
        return currentCal.component(.year, from: self)
    }
    var month: Int {
        return currentCal.component(.month, from: self)
    }
    var day: Int {
        return currentCal.component(.day, from: self)
    }
}
