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

extension Date {
    var weekday: String {
        let target = DateComponents(calendar: currentCal, year: year, month: month, day: day).date ?? .init()
        let day = Calendar.current.component(.weekday, from: target) - 1
        return Calendar.current.shortWeekdaySymbols[day]
    }
}
