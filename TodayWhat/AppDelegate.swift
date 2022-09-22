import Cocoa
import Then
import Combine
import LaunchAtLogin
import Network

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var refreshTimer: Timer?
    private let provider = NetworkProvider.shared
    private let menu = NSMenu().then {
        $0.title = ""
    }
    private let queue = DispatchQueue.global()
    private let monitor = NWPathMonitor()
    
    private var selectedPart: DisplayInfoPart = .breakfast
    private var meal: Meal? = nil
    private var timeTable: [TimeTable] = []
    private var bag = Set<AnyCancellable>()
    
    private let mealHeaderMenuItem = NSMenuItem().then {
        $0.title = "급식"
        $0.tag = 1
    }
    private let breakfastMenuItem = NSMenuItem().then {
        $0.title = "  🥞 아침"
        $0.keyEquivalent = "1"
        $0.state = .on
        $0.tag = 2
        $0.action = #selector(breakfastMenuAction)
    }
    private let lunchMenuItem = NSMenuItem().then {
        $0.title = "  🍱 점심"
        $0.keyEquivalent = "2"
        $0.tag = 3
        $0.action = #selector(lunchMenuAction)
    }
    private let dinnerMenuItem = NSMenuItem().then {
        $0.title = "  🍛 저녁"
        $0.keyEquivalent = "3"
        $0.tag = 4
        $0.action = #selector(dinnerMenuAction)
    }
    private let timetableHeaderMenuItem = NSMenuItem().then {
        $0.title = "시간표"
    }
    private let timeTableMenuItem = NSMenuItem().then {
        $0.title = "  🕰 시간표"
        $0.keyEquivalent = "4"
        $0.tag = 5
        $0.action = #selector(timeTableMenuAction)
    }
    private let reportMenuItem = NSMenuItem().then {
        $0.title = "💡 이슈"
        $0.tag = 6
        $0.action = #selector(reportMenuAction)
    }
    private let refreshMenuItem = NSMenuItem().then {
        $0.title = "💣 새로고침"
        $0.tag = 7
        $0.keyEquivalent = "r"
        $0.action = #selector(refreshMenuAction)
    }
    private let schoolSetMenuItem = NSMenuItem().then {
        $0.title = "🏫 학교 설정"
        $0.tag = 8
        $0.keyEquivalent = "d"
        $0.action = #selector(setSchoolMenuAction)
    }
    private let classGradeSetMenuItem = NSMenuItem().then {
        $0.title = "🪄 학년/반 설정"
        $0.tag = 9
        $0.keyEquivalent = "f"
        $0.action = #selector(setClassGradeMenuAction)
    }
    private let skipWeekendMenuItem = NSMenuItem().then {
        $0.title = UserDefaultsLocal.shared.skipWeekend ? "🔀 주말 스킵하지 않기" : "🔀 주말 스킵하기"
        $0.tag = 12
        $0.keyEquivalent = "g"
        $0.action = #selector(skipWeekendMenuAction)
    }
    private let settingMenuItem = NSMenuItem().then {
        $0.title = "⚙️ 설정"
        $0.tag = 10
        $0.keyEquivalent = "i"
        $0.action = #selector(settingMenuAction)
    }
    private let exitMenuItem = NSMenuItem().then {
        $0.title = "🚪 닫기"
        $0.tag = 11
        $0.keyEquivalent = "q"
        $0.action = #selector(quitMenuAction)
    }
    private let networkNotSatisfiedMenuItem = NSMenuItem().then {
        $0.title = "⚠️ 네트워크가 정상적이지 않아요!"
        $0.toolTip = "네트워크를 확인해주세요"
        $0.tag = Consts.networkTag
        $0.action = #selector(networkMenuAction)
    }
    private let stealingMenuMenuItem = NSMenuItem().then {
        $0.title = "🥷 메뉴판을 훔치는 중이에요..."
        $0.tag = 23
        $0.action = #selector(stealMenuAction)
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if UserDefaultsLocal.shared.grade == 0 { UserDefaultsLocal.shared.grade = 1 }
        if UserDefaultsLocal.shared.class == 0 { UserDefaultsLocal.shared.class = 1 }
        
        initialUI()
        
        if UserDefaultsLocal.shared.school == nil {
            setSchoolMenuAction()
            return
        }
        
        startRefreshTimer()
        startNetworkMonitoring()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        invalidateTimer()
        stopNetworkMonitoring()
        statusItem = nil
        bag.removeAll()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}

// MARK: - Selector
private extension AppDelegate {
    @objc func breakfastMenuAction() {
        selectedPart = .breakfast
        commonOptionMenuAction()
    }
    @objc func lunchMenuAction() {
        selectedPart = .lunch
        commonOptionMenuAction()
    }
    @objc func dinnerMenuAction() {
        selectedPart = .dinner
        commonOptionMenuAction()
    }
    @objc func timeTableMenuAction() {
        selectedPart = .timeTable
        commonOptionMenuAction()
    }
    @objc func reportMenuAction() {
        NSWorkspace.shared.open(URL(string: "https://github.com/baekteun/TodayWhat/issues") ?? .init(string: "https://www.google.com")!)
    }
    @objc func setSchoolMenuAction() {
        let alert = NSAlert()
        let schoolTextField = NSTextField(frame: .init(x: 0, y: 0, width: 300, height: 24))
        schoolTextField.placeholderString = UserDefaultsLocal.shared.school ?? "학교 이름을 입력해주세요!"
        
        alert.alertStyle = .informational
        alert.messageText = UserDefaultsLocal.shared.school == nil
        ? "학교를 설정합니다!"
        : "학교를 변경합니다!"
        alert.informativeText = "학교 이름을 입력해주세요. \n입력해주신 정보를 기반으로 급식/시간표의 정보를 가져옵니다"
        alert.accessoryView = schoolTextField
        alert.addButton(withTitle: "확인")
        if let school = UserDefaultsLocal.shared.school, !school.isEmpty {
            alert.addButton(withTitle: "취소")
        }
        alert.window.initialFirstResponder = schoolTextField
        
        if alert.runModal() == .alertFirstButtonReturn {
            let school = schoolTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if school.isEmpty {
                return
            }
            changeSchool(school: school)
        }
    }
    @objc func setClassGradeMenuAction() {
        let alert = NSAlert()
        
        let gradeLabel = NSTextField(frame: .init(x: 0, y: 0, width: 100, height: 24)).then {
            $0.stringValue = "학년"
            $0.isEditable = false
            $0.isBezeled = false
            $0.backgroundColor = .clear
            $0.sizeToFit()
        }
        let gradeTextField = NumberTextField(frame: .init(x: 0, y: 0, width: 150, height: 24)).then {
            $0.placeholderString = "\(UserDefaultsLocal.shared.grade)"
        }
        let classLabel = NSTextField(frame: .init(x: 0, y: 0, width: 100, height: 24)).then {
            $0.stringValue = "반"
            $0.isEditable = false
            $0.isBezeled = false
            $0.backgroundColor = .clear
            $0.sizeToFit()
        }
        let classTextField = NumberTextField(frame: .init(x: 0, y: 0, width: 150, height: 24)).then {
            $0.placeholderString = "\(UserDefaultsLocal.shared.class)"
        }
        
        let stack = NSStackView(frame: .init(x: 0, y: 0, width: 150, height: 120)).then {
            $0.spacing = 5
            $0.alignment = .leading
            [gradeLabel, gradeTextField, classLabel, classTextField].forEach($0.addArrangedSubview(_:))
        }
        
        alert.alertStyle = .informational
        alert.messageText = "학년/반 설정"
        alert.informativeText = "학년과 반을 입력해주세요. \n입력해주신 정보를 기반으로 시간표의 정보를 가져옵니다"
        alert.accessoryView = stack
        alert.addButton(withTitle: "확인")
        alert.addButton(withTitle: "취소")
        alert.window.initialFirstResponder = classTextField
        
        if alert.runModal() == .alertFirstButtonReturn {
            let `class` = classTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let grade = gradeTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            changeClassGrade(
                class: Int(`class`) ?? UserDefaultsLocal.shared.class,
                grade: Int(grade) ?? UserDefaultsLocal.shared.grade
            )
            return
        }
    }
    @objc func skipWeekendMenuAction() {
        UserDefaultsLocal.shared.skipWeekend = !UserDefaultsLocal.shared.skipWeekend
        skipWeekendMenuItem.title = UserDefaultsLocal.shared.skipWeekend ? "🔀 주말 스킵하지 않기" : "🔀 주말 스킵하기"
        refresh()
    }
    @objc func refreshMenuAction() {
        refresh()
    }
    @objc func settingMenuAction() {
        let alert = NSAlert()
        alert.messageText = "환경설정"
        let button = NSButton(checkboxWithTitle: "재시작시 자동 실행", target: nil, action: #selector(launchAtLoginToggleAction))
        button.state = LaunchAtLogin.isEnabled ? .on : .off
        alert.accessoryView = button
        
        if alert.runModal() == .alertFirstButtonReturn {
            return
        }
    }
    @objc func launchAtLoginToggleAction() {
        LaunchAtLogin.isEnabled = !LaunchAtLogin.isEnabled
    }
    @objc func quitMenuAction() {
        NSApplication.shared.terminate(self)
    }
    @objc func networkMenuAction() {}
    @objc func stealMenuAction() {}
}

// MARK: - Method
private extension AppDelegate {
    func initialUI() {
        [
            mealHeaderMenuItem, breakfastMenuItem, lunchMenuItem, dinnerMenuItem, timetableHeaderMenuItem, timeTableMenuItem, .separator(), reportMenuItem, .separator(), schoolSetMenuItem, classGradeSetMenuItem, skipWeekendMenuItem, .separator(), refreshMenuItem, settingMenuItem, exitMenuItem, networkNotSatisfiedMenuItem
        ].forEach(menu.addItem(_:))
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.image = NSImage(named: "BAG")
        statusItem?.menu = menu
        
        fetchItems()
    }
    func updateUI() {
        removeAllItem()
        if selectedPart == .timeTable {
            displayTimeTable()
        } else {
            displayMealList()
        }
        displaySchoolInfo()
    }
    func fetchItems() {
        if !menu.items.contains(stealingMenuMenuItem) {
            menu.addItem(stealingMenuMenuItem)
        }
        provider.fetchMealList().zip(provider.fetchTimeTable())
            .sink { [weak self] (meal, timetable) in
                guard let self = self else { return }
                self.meal = meal
                self.timeTable = timetable
                self.updateUI()
                guard self.menu.items.contains(self.stealingMenuMenuItem) else { return }
                self.menu.removeItem(self.stealingMenuMenuItem)
            }
            .store(in: &bag)

    }
    func displayTimeTable() {
        Array(Set(timeTable)).sorted(by: { $0.perio > $1.perio } ).forEach { timetable in
            let str = NSMutableAttributedString(string: "\(timetable.perio)교시\n\(timetable.content)")
            str.setAttributes([
                .font: NSFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: NSColor.textColor
            ], range: .init(location: 0, length: str.length))
            str.setFontForText(textToFind: "\(timetable.perio)교시", withFont: .systemFont(ofSize: 16, weight: .medium))
            str.setColorForText(textToFind: "\(timetable.perio)교시", withColor: .headerTextColor)
            let menuItem = NSMenuItem().then {
                $0.attributedTitle = str
                $0.tag = Consts.scheduleTag
                $0.isEnabled = true
            }
            self.menu.insertItem(menuItem, at: .zero)
        }
        if timeTable.isEmpty {
            let menuItem = NSMenuItem().then {
                $0.title = "시간표을 찾을 수 없어요!"
                $0.tag = Consts.mealTag
            }
            menu.insertItem(menuItem, at: .zero)
        }
    }
    func displayMealList() {
        let arr: [String]
        switch selectedPart {
        case .breakfast:
            arr = meal?.breakfast ?? []
        case .lunch:
            arr = meal?.lunch ?? []
        case .dinner:
            arr = meal?.dinner ?? []
        case .timeTable:
            arr = []
        }
        menu.insertItem(.separator(), at: .zero)
        arr.reversed().forEach { meal in
            let firstInteger = meal.first { str in
                str == "(" || (Int(String(str)) != nil && str != "/")
            }.map { String($0) } ?? " "
            var split = meal.split(separator: Character(firstInteger), maxSplits: 1).map { String($0) }
            if split.count == 2 && firstInteger != "*" {
                var prev = split[1].map { String($0) }
                prev.insert(firstInteger, at: .zero)
                split[1] = prev.joined(separator: "")
            }
            let res = split.joined(separator: "\n")
            let str = NSMutableAttributedString(string: res + "\n")
            str.setAttributes([
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.textColor
            ], range: .init(location: 0, length: str.length))
            str.setFontForText(textToFind: split.first ?? "", withFont: .systemFont(ofSize: 16, weight: .medium))
            str.setColorForText(textToFind: split.first ?? "", withColor: .headerTextColor)
            let menuItem = NSMenuItem().then {
                $0.attributedTitle = str
                $0.tag = Consts.mealTag
                $0.isEnabled = true
            }
            self.menu.insertItem(menuItem, at: .zero)
        }
        
        if arr.isEmpty {
            let menuItem = NSMenuItem().then {
                $0.title = "\(selectedPart.display)을 찾을 수 없어요!"
                $0.tag = Consts.mealTag
            }
            menu.insertItem(menuItem, at: .zero)
        }
        self.menu.insertItem(.separator(), at: .zero)
    }
    func displaySchoolInfo() {
        guard let school = UserDefaultsLocal.shared.school, !school.isEmpty else {
            let str = NSMutableAttributedString(string: "❌ 아직 등록된 학교가 없어요!")
            str.setAttributes([
                .foregroundColor: NSColor.red
            ], range: .init(location: 0, length: str.length))
            let descriptionMenu = NSMenuItem().then {
                $0.attributedTitle = str
                $0.tag = Consts.scheduleTag
                $0.isEnabled = true
            }
            menu.insertItem(descriptionMenu, at: .zero)
            return
        }
        let info = selectedPart == .timeTable
        ? "🏫 \(school) \(UserDefaultsLocal.shared.grade)학년 \(UserDefaultsLocal.shared.class)반"
        : "🏫 \(school) (\(selectedPart.display))"
        let str = NSMutableAttributedString(string: info)
        str.setAttributes([
            .foregroundColor: NSColor.red
        ], range: .init(location: 0, length: str.length))
        let descriptionMenuItem = NSMenuItem().then {
            $0.attributedTitle = str
            $0.tag = Consts.scheduleTag
            $0.isEnabled = true
        }
        menu.insertItem(.separator(), at: .zero)
        menu.insertItem(descriptionMenuItem, at: .zero)
    }
    func removeAllItem() {
        menu.items.filter { [Consts.mealTag, Consts.scheduleTag].contains($0.tag) }.forEach(menu.removeItem(_:))
    }
    func changeSchool(school: String) {
        provider.searchSchool(name: school)
            .sink { _ in
            } receiveValue: { [weak self] school in
                UserDefaultsLocal.shared.school = school.schoolName
                UserDefaultsLocal.shared.orgCode = school.orgCode
                UserDefaultsLocal.shared.code = school.schoolCode
                UserDefaultsLocal.shared.schoolType = school.schoolType
                self?.refresh()
            }
            .store(in: &bag)
    }
    func changeClassGrade(class: Int, grade: Int) {
        UserDefaultsLocal.shared.class = `class`
        UserDefaultsLocal.shared.grade = grade
        refresh()
    }
    func commonOptionMenuAction() {
        let index = DisplayInfoPart.allCases.firstIndex(of: selectedPart) ?? 0
        [breakfastMenuItem, lunchMenuItem, dinnerMenuItem, timeTableMenuItem].enumerated().forEach { item in
            item.element.state = index == item.offset ? .on : .off
        }
        
        updateUI()
    }
    func refresh() {
        invalidateTimer()
        fetchItems()
        startRefreshTimer()
    }
}

// MARK: - Timer
private extension AppDelegate {
    func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: 60 * 60 * 6,
            repeats: true,
            block: { [weak self] _ in
                self?.refresh()
            }
        )
    }
    func invalidateTimer() {
        refreshTimer?.invalidate()
    }
}

// MARK: - Network Monitoring
private extension AppDelegate {
    func startNetworkMonitoring() {
        monitor.start(queue: queue)
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            switch path.status {
            case .satisfied:
                guard self.menu.items.contains(self.networkNotSatisfiedMenuItem) else { return }
                self.menu.removeItem(self.networkNotSatisfiedMenuItem)
            case .unsatisfied, .requiresConnection:
                guard !self.menu.items.contains(self.networkNotSatisfiedMenuItem) else { return }
                self.menu.addItem(self.networkNotSatisfiedMenuItem)
            @unknown default:
                break
            }
        }
    }
    func stopNetworkMonitoring() {
        monitor.cancel()
    }
}
