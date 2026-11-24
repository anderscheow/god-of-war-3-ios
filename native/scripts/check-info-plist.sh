#!/usr/bin/env bash
# The iOS 27 SDK needs two things in the built app's Info.plist (iOS & iPadOS 27 release notes, UIKit):
#  - the UIKit scene life cycle: a UIApplicationSceneManifest scene with a delegate class, or the app
#    fails to launch (TN3187);
#  - a launch screen: UILaunchStoryboardName, UILaunchStoryboards, UILaunchScreen or UILaunchScreens.
# The app's Info.plist comes from `expo prebuild` (the SDK's template), not from this repo, so this
# checks the real result instead of trusting the template.
# Usage: check-info-plist.sh <the .app or its Info.plist>. Needs plutil (macOS).
set -euo pipefail

target=${1:?usage: check-info-plist.sh <the .app or its Info.plist>}
plist=$target
[ -d "$target" ] && plist="$target/Info.plist"
[ -f "$plist" ] || { echo "no Info.plist at $plist" >&2; exit 2; }

fail=0

scene=UIApplicationSceneManifest.UISceneConfigurations.UIWindowSceneSessionRoleApplication.0
if delegate=$(plutil -extract "$scene.UISceneDelegateClassName" raw -o - "$plist" 2>/dev/null) && [ -n "$delegate" ]; then
  echo "scene life cycle: ok (UISceneDelegateClassName $delegate)"
else
  echo "::error::$plist has no UIApplicationSceneManifest scene with a UISceneDelegateClassName: an app built with the iOS 27 SDK fails to launch (TN3187)"
  fail=1
fi

launch=
for key in UILaunchStoryboardName UILaunchStoryboards UILaunchScreen UILaunchScreens; do
  if plutil -type "$key" "$plist" >/dev/null 2>&1; then launch=$key; break; fi
done
if [ -n "$launch" ]; then
  echo "launch screen: ok ($launch)"
else
  echo "::error::$plist has no UILaunchStoryboardName, UILaunchStoryboards, UILaunchScreen or UILaunchScreens: apps built with the iOS 27 SDK need a launch screen"
  fail=1
fi

exit "$fail"
