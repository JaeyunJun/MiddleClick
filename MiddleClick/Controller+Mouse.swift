import CoreGraphics
import Foundation
import CoreFoundation
import QuartzCore

extension Controller {
  private static let state = GlobalState.shared
  private static let kCGMouseButtonCenter = Int64(CGMouseButton.center.rawValue)
  private static let config = Config.shared

  // Track event counts for debugging
  private static var eventCount: Int = 0
  private static var lastLogTime: TimeInterval = 0
  
  static let mouseEventHandler = CGEventController {
    _, type, event, _ in
    
    // Debug: Log event types periodically
    #if DEBUG
    eventCount += 1
    let now = CACurrentMediaTime()
    if now - lastLogTime > 5.0 {
      log.debug("Received \(eventCount) events in 5s, last type: \(type.rawValue)")
      eventCount = 0
      lastLogTime = now
    }
    #endif
    
    // Fast path: only process click events
    // Using switch for better performance than multiple comparisons
    switch type {
    case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp:
      break
    default:
      return Unmanaged.passUnretained(event)
    }
    
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
