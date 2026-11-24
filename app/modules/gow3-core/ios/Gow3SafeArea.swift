// SPDX-License-Identifier: GPL-3.0-or-later
// The app window's safe-area insets for the React Native launcher, which has no safe-area API of its
// own. On iPhone Duo they change as the device folds and rotates, so JS asks again on every resize.
import UIKit

enum Gow3SafeArea {
  /// Points; all zero until a scene has a key window. Main thread only.
  static func current() -> [String: Double] {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    let inset = scene?.keyWindow?.safeAreaInsets ?? .zero
    return ["top": inset.top, "left": inset.left, "bottom": inset.bottom, "right": inset.right]
  }
}
