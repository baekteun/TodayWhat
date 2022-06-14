import Foundation
import Cocoa

extension NSMutableAttributedString {
    func setColorForText(textToFind: String, withColor color: NSColor) {
        let range: NSRange = self.mutableString.range(of: textToFind, options: .caseInsensitive)
        self.addAttribute(NSAttributedString.Key.foregroundColor, value: color, range: range)
    }
    func setFontForText(textToFind: String, withFont font: NSFont) {
        let range : NSRange = self.mutableString.range(of: textToFind,options: .caseInsensitive)
        self.addAttribute(NSAttributedString.Key.font, value: font, range: range)
    }
}
