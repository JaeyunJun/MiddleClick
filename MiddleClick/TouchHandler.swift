import MoreTouchCore
import MultitouchSupport

@MainActor class TouchHandler {
  static let shared = TouchHandler()
  private static let config = Config.shared
  private init() {
    Self.config.$minimumFingers.onSet {
      Self.fingersQua = $0
    }
  }

  private static var fingersQua = config.minimumFingers
  private static let allowMoreFingers = config.allowMoreFingers
  private static let maxDistanceDelta = config.maxDistanceDelta
  private static let maxTimeDelta = config.maxTimeDelta
  private static let fourFingerAction = config.fourFingerAction
  private static let threeFingerSwipe = config.threeFingerSwipe
  private static let swipeThreshold = config.swipeThreshold

  private var threeFingerSwipeStartPos: SIMD2<Float> = .zero
  private var threeFingerSwipeTriggered = false
  private var lastFingerCount: Int32 = 0

  private let touchCallback: MTFrameCallbackFunction = {
    _, data, nFingers, _, _ in
    let handler = TouchHandler.shared
    
    // Early return if finger count hasn't changed and no active gesture
    if nFingers == handler.lastFingerCount {
      // Only process swipe if we're already tracking it
      if threeFingerSwipe && nFingers == 3 && !handler.threeFingerSwipeStartPos.isZero {
        handler.processThreeFingerSwipe(data: data, nFingers: nFingers)
      }
      return
    }
    
    // Finger count changed - check if we need to process
    guard !AppUtils.isIgnoredAppBundle() else { return }

    let state = GlobalState.shared

    // Early return if no relevant gestures are active
    guard threeFingerSwipe || fourFingerAction || nFingers >= fingersQua else {
      handler.lastFingerCount = nFingers
      return
    }

    // Update state when finger count changes
    handler.lastFingerCount = nFingers
    
    // 3-finger middle click: only exactly 3 fingers (ignore allowMoreFingers to prevent conflicts)
    if nFingers == fingersQua || nFingers == 0 {
      state.threeDown = nFingers == fingersQua
    }
    
    // 4-finger action: only when exactly 4 fingers
    if fourFingerAction && (nFingers == 4 || nFingers == 0) {
      state.fourDown = nFingers == 4
    }

    // Handle 3-finger swipe gesture
    if threeFingerSwipe {
      if nFingers == 3 {
        handler.processThreeFingerSwipe(data: data, nFingers: nFingers)
      } else if nFingers == 0 {
        handler.handleThreeFingerSwipeEnd()
      }
    }

    return
  }

  private func processThreeFingerSwipe(data: UnsafePointer<MTTouch>?, nFingers: Int32) {
    guard let data = data else { return }
    
    var currentPos: SIMD2<Float> = .zero
    for touch in UnsafeBufferPointer(start: data, count: 3) {
      currentPos += SIMD2(touch.normalizedVector.position)
    }
    currentPos /= 3.0 // Average position
    
    if threeFingerSwipeStartPos.isZero {
      threeFingerSwipeStartPos = currentPos
      threeFingerSwipeTriggered = false
    } else if !threeFingerSwipeTriggered {
      // Check if swipe threshold is met
      let horizontalDelta = currentPos.x - threeFingerSwipeStartPos.x
      
      if abs(horizontalDelta) > Self.swipeThreshold {
        // Trigger immediately
        if horizontalDelta > 0 {
          Self.emulateMouseButton(3) // Left to right: Mouse 4
        } else {
          Self.emulateMouseButton(4) // Right to left: Mouse 5
        }
        threeFingerSwipeTriggered = true
      }
    }
  }
  
  private func handleThreeFingerSwipeEnd() {
    // Reset state when fingers are lifted
    threeFingerSwipeStartPos = .zero
    threeFingerSwipeTriggered = false
  }

  private static func emulateMouseButton(_ buttonNumber: Int64) {
    let location = CGEvent(source: nil)?.location ?? .zero
    
    // Create mouse button event
    if let mouseDown = CGEvent(
      mouseEventSource: nil,
      mouseType: .otherMouseDown,
      mouseCursorPosition: location,
      mouseButton: .center
    ) {
      mouseDown.setIntegerValueField(.mouseEventButtonNumber, value: buttonNumber)
      mouseDown.post(tap: .cghidEventTap)
    }
    
    if let mouseUp = CGEvent(
      mouseEventSource: nil,
      mouseType: .otherMouseUp,
      mouseCursorPosition: location,
      mouseButton: .center
    ) {
      mouseUp.setIntegerValueField(.mouseEventButtonNumber, value: buttonNumber)
      mouseUp.post(tap: .cghidEventTap)
    }
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
  var isZero: Bool { x == 0 && y == 0 }
}
