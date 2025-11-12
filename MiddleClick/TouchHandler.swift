import MoreTouchCore
import MultitouchSupport

@MainActor class TouchHandler {
  static let shared = TouchHandler()
  private static let config = Config.shared
  private init() {
    Self.config.$tapToClick.onSet {
      self.tapToClick = $0
    }
    Self.config.$minimumFingers.onSet {
      Self.fingersQua = $0
    }
  }

  /// stored locally, since accessing the cache is more CPU-expensive than a local variable
  private var tapToClick = config.tapToClick

  private static var fingersQua = config.minimumFingers
  private static let allowMoreFingers = config.allowMoreFingers
  private static let maxDistanceDelta = config.maxDistanceDelta
  private static let maxTimeDelta = config.maxTimeDelta
  private static let fourFingerAction = config.fourFingerAction

  private var maybeMiddleClick = false
  private var maybeFourFingerAction = false
  private var touchStartTime: Date?
  private var fourFingerTouchStartTime: Date?
  private var middleClickPos1: SIMD2<Float> = .zero
  private var middleClickPos2: SIMD2<Float> = .zero
  private var fourFingerPos1: SIMD2<Float> = .zero
  private var fourFingerPos2: SIMD2<Float> = .zero

  private let touchCallback: MTFrameCallbackFunction = {
    _, data, nFingers, _, _ in
    guard !AppUtils.isIgnoredAppBundle() else { return }

    let state = GlobalState.shared

    state.threeDown =
    allowMoreFingers ? nFingers >= fingersQua : nFingers == fingersQua
    
    state.fourDown = nFingers == 4

    let handler = TouchHandler.shared

    guard handler.tapToClick else { return }

    guard nFingers != 0 else {
      handler.handleTouchEnd()
      handler.handleFourFingerTouchEnd()
      return
    }

    // Handle 4-finger tap gesture
    if nFingers == 4 && fourFingerAction {
      let isFourFingerStart = handler.fourFingerTouchStartTime == nil
      if isFourFingerStart {
        handler.fourFingerTouchStartTime = Date()
        handler.maybeFourFingerAction = true
        handler.fourFingerPos1 = .zero
      } else if handler.maybeFourFingerAction, let startTime = handler.fourFingerTouchStartTime {
        let elapsedTime = -startTime.timeIntervalSinceNow
        if elapsedTime > maxTimeDelta {
          handler.maybeFourFingerAction = false
        }
      }
      handler.processFourFingerTouches(data: data, nFingers: nFingers)
      return
    }
    
    // Handle 3-finger (or custom) middle click gesture
    guard !(nFingers < fingersQua) else { return }
    
    let isTouchStart = nFingers > 0 && handler.touchStartTime == nil
    if isTouchStart {
      handler.touchStartTime = Date()
      handler.maybeMiddleClick = true
      handler.middleClickPos1 = .zero
    } else if handler.maybeMiddleClick, let touchStartTime = handler.touchStartTime {
      // Timeout check for middle click
      let elapsedTime = -touchStartTime.timeIntervalSinceNow
      if elapsedTime > maxTimeDelta {
        handler.maybeMiddleClick = false
      }
    }

    if !allowMoreFingers && nFingers > fingersQua {
      handler.resetMiddleClick()
    }

    let isCurrentFingersQuaAllowed = allowMoreFingers ? nFingers >= fingersQua : nFingers == fingersQua
    guard isCurrentFingersQuaAllowed else { return }

    handler.processTouches(data: data, nFingers: nFingers)

    return
  }

  private func processTouches(data: UnsafePointer<MTTouch>?, nFingers: Int32) {
    guard let data = data else { return }

    if maybeMiddleClick {
      middleClickPos1 = .zero
    } else {
      middleClickPos2 = .zero
    }

//    TODO: Wait, what? Why is this iterating by fingersQua instead of nFingers, given that e.g. "allowMoreFingers" exists?
    for touch in UnsafeBufferPointer(start: data, count: Self.fingersQua) {
      let pos = SIMD2(touch.normalizedVector.position)
      if maybeMiddleClick {
        middleClickPos1 += pos
      } else {
        middleClickPos2 += pos
      }
    }

    if maybeMiddleClick {
      middleClickPos2 = middleClickPos1
      maybeMiddleClick = false
    }
  }

  private func processFourFingerTouches(data: UnsafePointer<MTTouch>?, nFingers: Int32) {
    guard let data = data else { return }

    if maybeFourFingerAction {
      fourFingerPos1 = .zero
    } else {
      fourFingerPos2 = .zero
    }

    for touch in UnsafeBufferPointer(start: data, count: 4) {
      let pos = SIMD2(touch.normalizedVector.position)
      if maybeFourFingerAction {
        fourFingerPos1 += pos
      } else {
        fourFingerPos2 += pos
      }
    }

    if maybeFourFingerAction {
      fourFingerPos2 = fourFingerPos1
      maybeFourFingerAction = false
    }
  }

  private func resetMiddleClick() {
    maybeMiddleClick = false
    middleClickPos1 = .zero
  }
  
  private func resetFourFingerAction() {
    maybeFourFingerAction = false
    fourFingerPos1 = .zero
  }

  private func handleTouchEnd() {
    guard let startTime = touchStartTime else { return }

    let elapsedTime = -startTime.timeIntervalSinceNow
    touchStartTime = nil

    guard middleClickPos1.isNonZero && elapsedTime <= Self.maxTimeDelta else { return }

    let delta = middleClickPos1.delta(to: middleClickPos2)
    if delta < Self.maxDistanceDelta && !shouldPreventEmulation() {
      Self.emulateMiddleClick()
    }
  }
  
  private func handleFourFingerTouchEnd() {
    guard let startTime = fourFingerTouchStartTime else { return }

    let elapsedTime = -startTime.timeIntervalSinceNow
    fourFingerTouchStartTime = nil

    guard fourFingerPos1.isNonZero && elapsedTime <= Self.maxTimeDelta else { return }

    let delta = fourFingerPos1.delta(to: fourFingerPos2)
    if delta < Self.maxDistanceDelta {
      Self.emulateCommandW()
    }
  }

  private static func emulateMiddleClick() {
    // get the current pointer location
    let location = CGEvent(source: nil)?.location ?? .zero
    let buttonType: CGMouseButton = .center

    postMouseEvent(type: .otherMouseDown, button: buttonType, location: location)
    postMouseEvent(type: .otherMouseUp, button: buttonType, location: location)
  }
  
  private static func emulateCommandW() {
    // Create Command+W key event
    let keyCode: CGKeyCode = 13 // W key
    
    // Key down with Command
    if let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) {
      keyDownEvent.flags = .maskCommand
      keyDownEvent.post(tap: .cghidEventTap)
    }
    
    // Key up
    if let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) {
      keyUpEvent.post(tap: .cghidEventTap)
    }
  }

  private func shouldPreventEmulation() -> Bool {
    guard let naturalLastTime = GlobalState.shared.naturalMiddleClickLastTime else { return false }

    let elapsedTimeSinceNatural = -naturalLastTime.timeIntervalSinceNow
    return elapsedTimeSinceNatural <= Self.maxTimeDelta * 0.75 // fine-tuned multiplier
  }

  private static func postMouseEvent(
    type: CGEventType, button: CGMouseButton, location: CGPoint
  ) {
    CGEvent(
      mouseEventSource: nil, mouseType: type, mouseCursorPosition: location,
      mouseButton: button
    )?.post(tap: .cghidEventTap)
  }

  private var currentDeviceList: [MTDevice] = []
  func registerTouchCallback() {
    currentDeviceList = MTDevice.createList()
    currentDeviceList.forEach { $0.registerAndStart(touchCallback) }
  }
  func unregisterTouchCallback() {
    currentDeviceList.forEach { $0.unregisterAndStop(touchCallback) }
    currentDeviceList.removeAll()
  }
}

extension SIMD2 where Scalar == Float {
  init(_ point: MTPoint) { self.init(point.x, point.y) }
}
extension SIMD2 where Scalar: FloatingPoint {
  func delta(to other: SIMD2) -> Scalar {
    return abs(x - other.x) + abs(y - other.y)
  }

  var isNonZero: Bool { x != 0 || y != 0 }
}
