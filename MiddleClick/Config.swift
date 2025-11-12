import ConfigCore

final class Config: ConfigCore {
  required init() {
    Self.options.cacheAll = true
  }

  @UserDefault("fingers")
  var minimumFingers = 3

  @UserDefault var allowMoreFingers = false
  
  @UserDefault var fourFingerAction = true  // true: Command+W, false: disabled
  
  @UserDefault var threeFingerSwipe = true  // true: Mouse 4/5 buttons, false: disabled
  
  @UserDefault var swipeThreshold: Float = 0.15  // Minimum horizontal distance for swipe detection

  @UserDefault var maxDistanceDelta: Float = 0.05

  /// In milliseconds
  @UserDefault(transformGet: { $0 / 1000 })
  var maxTimeDelta = 300.0

  @UserDefault var ignoredAppBundles = Set<String>()
}
