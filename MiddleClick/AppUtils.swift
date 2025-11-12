import AppKit

enum AppUtils {
  @MainActor static func warningAlert(title: String, message: String) -> NSAlert {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.alertStyle = .warning
    alert.addButton(withTitle: "OK")
//    alert.runModal()
    return alert
  }
}
