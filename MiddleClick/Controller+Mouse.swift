import CoreGraphics
import Foundation
import CoreFoundation

extension Controller {
  private static let state = GlobalState.shared
  private static let kCGMouseButtonCenter = Int64(CGMouseButton.center.rawValue)
  private static let config = Config.shared

  static let mouseEventHandler = CGEventController {
    _, type, event, _ in
    
    // Early return for irrelevant event types
    guard type == .leftMouseDown || type == .rightMouseDown || 
          type == .leftMouseUp || type == .rightMouseUp else {
      return Unmanaged.passUnretained(event)
    }
    
    guard !AppUtils.isIgnoredAppBundle() else { return Unmanaged.passUnretained(event) }
    
    let returnedEvent = Unmanaged.passUnretained(event)

    let isMouseDown = type == .leftMouseDown || type == .rightMouseDown
    let isMouseUp = type == .leftMouseUp || type == .rightMouseUp

    // Handle 3-finger click
    if state.threeDown && isMouseDown {
      state.wasThreeDown = true
      event.type = .otherMouseDown
      event.setIntegerValueField(.mouseEventButtonNumber, value: kCGMouseButtonCenter)
    }

    if state.wasThreeDown && isMouseUp {
      state.wasThreeDown = false
      event.type = .otherMouseUp
      event.setIntegerValueField(.mouseEventButtonNumber, value: kCGMouseButtonCenter)
    }

    // Handle 4-finger click
    if config.fourFingerAction {
      if state.fourDown && isMouseDown {
        state.wasFourDown = true
        
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

      if state.wasFourDown && isMouseUp {
        state.wasFourDown = false
        // Suppress the original click
        return nil
      }
    }

    return returnedEvent
  }
}
