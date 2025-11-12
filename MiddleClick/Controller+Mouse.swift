import CoreGraphics
import Foundation
import CoreFoundation

extension Controller {
  private static let state = GlobalState.shared
  private static let kCGMouseButtonCenter = Int64(CGMouseButton.center.rawValue)
  private static let config = Config.shared

  static let mouseEventHandler = CGEventController {
    _, type, event, _ in

    let returnedEvent = Unmanaged.passUnretained(event)
    guard !AppUtils.isIgnoredAppBundle() else { return returnedEvent }

    // Handle 3-finger click
    if state.threeDown && (type == .leftMouseDown || type == .rightMouseDown) {
      state.wasThreeDown = true
      state.threeDown = false
      state.naturalMiddleClickLastTime = Date()
      event.type = .otherMouseDown

      event.setIntegerValueField(.mouseEventButtonNumber, value: kCGMouseButtonCenter)
    }

    if state.wasThreeDown && (type == .leftMouseUp || type == .rightMouseUp) {
      state.wasThreeDown = false
      event.type = .otherMouseUp

      event.setIntegerValueField(.mouseEventButtonNumber, value: kCGMouseButtonCenter)
    }

    // Handle 4-finger click
    if config.fourFingerAction && state.fourDown && (type == .leftMouseDown || type == .rightMouseDown) {
      state.wasFourDown = true
      state.fourDown = false
      
      // Emulate Command+W
      let keyCode: CGKeyCode = 13 // W key
      if let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) {
        keyDownEvent.flags = .maskCommand
        keyDownEvent.post(tap: .cghidEventTap)
      }
      if let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) {
        keyUpEvent.post(tap: .cghidEventTap)
      }
      
      // Suppress the original click
      return nil
    }

    if state.wasFourDown && (type == .leftMouseUp || type == .rightMouseUp) {
      state.wasFourDown = false
      // Suppress the original click
      return nil
    }

    return returnedEvent
  }
}
