import Cocoa

final class NumberTextField: NSTextField {
  // 1
  private var digit: Int?

  override func textDidChange(_ notification: Notification) {
    // 2
    if stringValue.isEmpty || (stringValue.count == 1 && Int(stringValue) != nil) {
      digit = Int(stringValue)
    // 3
    } else {
      stringValue = digit != nil ? String(digit!) : ""
    }
  }
}
