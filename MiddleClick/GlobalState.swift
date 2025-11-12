import Foundation

@MainActor
final class GlobalState {
  static let shared = GlobalState()
  private init() {}

  var threeDown = false
  var wasThreeDown = false
  var fourDown = false
  var wasFourDown = false
}
