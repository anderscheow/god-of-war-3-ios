# iOS 27 SDK / iPhone Duo audit: gow3-ios (Olympus)

Date: 2026-11-24. Scope: this repo (`app/`, `native/`, `.github/workflows/ios.yml`), excluding `ref/` and vendored shadPS4.
Status: **audit only. No project file was edited.** The change plan below waits for your approval.

## Bottom line

1. **The hard iOS 27 requirements are probably already met**, and by the Expo template, not by this repo. The SDK 58 template ships a `SceneDelegate`, a `UIApplicationSceneManifest` and a launch storyboard. Nothing here needs fixing yet. One caveat: I read the template, not a built IPA, so a CI assertion on the real `Info.plist` is step 1.
2. **The biggest Duo issue is not in your checklist.** CI builds with `macos-26` + `latest-stable` Xcode (`ios.yml:29,37`). Without Xcode 27.1+, Duo runs the app letterboxed in the centre of the inner display, and left of the status bar and camera on the outer display. Moving to the 27.x SDK is also what makes the scene-lifecycle rule enforceable.
3. **There is no Liquid Glass opt-out to remove or keep.** Apple ignores `UIDesignRequiresCompatibility` for iOS 27 SDK builds, and the repo never set it.
4. **No biometric code exists**, so the Face ID check is a clean negative.
5. **Real work is small and sits in two places.** The native game view and touch controls (`UIScreen.main` fallbacks, reserved regions, orientation lock), and the RN launcher (hard-coded 58 pt top inset, custom tab bar).
6. **The real risk is runtime, not static.** Folding mid-game forces a swapchain recreate in the GPU window code. Nothing in the repo shows that has been tested.

## Findings by criterion

### 1. UIScene lifecycle (TN3187): no gap found at template level
- iOS 27 SDK builds that don't adopt the scene lifecycle fail to launch. [iOS 27 release notes → UIKit → Deprecations (141837548)]; [TN3187].
- The repo has no `AppDelegate`, `SceneDelegate` or `Info.plist` for the main app. `app.json` carries no `UIApplicationSceneManifest`. `expo prebuild -p ios --clean` (`ios.yml:109`) generates all of it.
- `expo-template-bare-minimum@58.0.35` (what SDK 58 prebuild pulls) contains `SceneDelegate.swift` (`ExpoAppSceneDelegate`) and an `Info.plist` with `UIApplicationSceneManifest` → `UIWindowSceneSessionRoleApplication` → `$(PRODUCT_MODULE_NAME).SceneDelegate`. `@expo/prebuild-config@58.0.20` has no splash/scene/launch rewrites that would remove them.
- Project code is already scene-aware: `Gow3GameView.swift:80` finds the key window via `connectedScenes`.
- Residual items:
  - `Gow3Pairing.swift:154,173` read `UIApplication.shared.applicationState`. This still works under scenes. TN3187 maps lifecycle events to scene delegate methods, so this is optional cleanup.
  - `native/jit-helper/Info.plist` is an app extension (`NSExtensionPointIdentifier com.apple.ar.viewer`) with no scene manifest. I infer extensions are outside the app-level rule. I did not find Apple text saying so.

### 2. Launch screen: present via template
- iOS 27.0 SDK apps must have `UILaunchStoryboardName`, `UILaunchStoryboards`, `UILaunchScreen` or `UILaunchScreens`. Apple's stated consequence is App Store rejection. [iOS 27 release notes → UIKit → New Features (168247372)].
- The template sets `UILaunchStoryboardName = SplashScreen` and ships `SplashScreen.storyboard`.
- `app.json` has no `splash` block and `expo-splash-screen` is not in `package.json`, so you rely entirely on the template default. Confirm in the built plist.
- You sideload only, so the App Store rejection rule does not apply to you.

### 3. Liquid Glass opt-out keys: nothing to remove
- `UIDesignRequiresCompatibility`: absent from `app.json`. Apple: "The system ignores this key when you build for iOS 27 or later." [UIDesignRequiresCompatibility]. The key only matters for iOS 26 SDK builds. [Adopting Liquid Glass] still mentions it, but the key page is newer and controls.
- `UIRequiresFullScreen`: absent. Apple lists it as available iOS 9–26 only. [UIRequiresFullScreen]
- Impact: the launcher is drawn by React Native, so Liquid Glass reaches mostly system UI (status bar, alerts, share sheet). This is my inference, not an Apple statement.
- Secondary sources say the key was "removed". Apple's page says "ignored". I used Apple's wording.

### 4. UIScreen.main, fixed sizes, split views, size classes
| Item | Location | Verdict |
|---|---|---|
| `UIScreen.main.maximumFramesPerSecond` fallback | `Gow3GameView.swift:57` | Replace. [Duo hub, Step 2] |
| `UIScreen.main.nativeScale` fallback | `Gow3GameView.swift:72` | Replace. [Duo hub, Step 2] |
| Surface size from `view.bounds` in `viewDidLayoutSubviews`, republished on every layout | `Gow3GameView.swift:70-76` | Correct pattern. [Duo hub: re-read size on change] |
| Swapchain recreated from new view size | `window_ios.mm:153-157` | Good design, untested on fold. See risks. |
| Landscape-only lock + `.landscapeRight` | `Gow3GameView.swift:64-65` | Decision needed (P1-c). [Duo hub: orientation is not shape] |
| Touch controls anchored to `safeAreaInsets` only | `Gow3TouchControls.swift:265-268` | Add reserved regions. [Duo article: reserved regions] |
| Touch control scale `min(h/400, 1.25)`, relative not device-fixed | `Gow3TouchControls.swift:268` | OK |
| `paddingTop: 58` top inset, hard-coded | `App.tsx:500` | Fix. [Duo article: size relative to container] |
| Custom RN bottom tab bar (plain `View`) | `App.tsx:486-490`, `styles.tabBar:563` | Will not go vertical. Option, not defect. See P2. |
| Blurred backdrop `Image`, 460 pt tall, default cover | `App.tsx:278,498` | No action. The 40 pt blur makes cropping harmless. |
| `UIWindow(frame:)`, `UIApplication.windows`, `statusBar*` accessors, `userInterfaceIdiom`, size-class checks | none | Clean |
| `UISplitViewController` / `NavigationSplitView` | none | **No split views to adapt** |
| `supportsTablet: false` (iPhone-only) | `app.json` | Still resizes on Duo per the hub for iOS 27 SDK builds |

### 5. Biometrics
- No `LAContext`, `LocalAuthentication`, `biometryType`, `Face ID` or `NSFaceIDUsageDescription` anywhere outside `ref/` and vendored code. Nothing to fix.
- Your Duo premise: press reports say Touch ID, no Face ID (side-button sensor). The iOS 27.3 beta adds "Unlock with Front Camera", lock screen only. Apple told Gizmodo it lacks Face ID/Touch ID protections. I found no LocalAuthentication API exposing it. I read search snippets only, not the full articles, and found **no Apple documentation** stating this. [MacRumors] [Gizmodo] [Tom's Guide]
- If you add biometrics later: branch on `LAContext.biometryType`, never assume `.faceID`.

## Change plan (nothing below is applied)

**P0, gate: build SDK and proof.**
- a. Add a CI step after prebuild that fails unless the generated `Info.plist` has `UIApplicationSceneManifest` and a `UILaunchStoryboardName` (`plutil -p`). This is cheap and turns my template-based inference into a check.
- b. Decide the 27.x SDK move. GitHub's Xcode 27 runner image is GA (labels `xcode-27`, `xcode-27-xlarge`, runs macOS 27; confirm against the runner-images README). The Duo hub says 27.0 gives the inner display minus the status bar, and **27.1 or later** gives full display with vertical bars.
- Cost: the native cache key includes the Xcode version (`ios.yml:45`), so FEX and MoltenVK rebuild against the new SDK. A new SDK/compiler may expose build breaks I can't predict.

**P1, small native changes.**
- a. `Gow3GameView.swift:57,72`: drop `UIScreen.main`. Use `view.window?.windowScene?.screen`, and `traitCollection.displayScale` or the scene screen's `nativeScale`, keeping the `min(…, 2)` cap.
- b. `Gow3TouchControls.swift`: in `layoutSubviews`, read `reservedRegions(kind:options:)` and keep sticks and buttons out of fold and camera regions. Unknown: whether `safeAreaInsets` already covers them. Settle it in the Duo simulator before writing code.
- c. Decision for you, orientation lock:
  - (A) Keep `.landscape`. This is least risk now and the game is 16:9. Duo's inner display may not be landscape-shaped.
  - (B) Drop the lock and rely on bounds. This follows the hub advice, but I can't confirm the renderer handles a portrait or square surface. The swapchain does follow the view size.
  - I recommend (A) first, then test.
- d. `App.tsx:500`: replace the 58 pt inset with real safe-area insets.
  - (A) `react-native-safe-area-context`. This adds a dependency; check the SDK 58 version with `npx expo install`.
  - (B) Expose `safeAreaInsets` from `gow3-core`. This adds no dependency but is more custom native code.

**P2, optional.**
- `Gow3CoreModule.swift:282`: `canOpenURL` is deprecated in iOS 27 (release notes, 179874781). The replacement is "attempt to open and handle failure", which would **launch StikDebug as a probe side effect**. Options: keep `canOpenURL` until it breaks, or drop the probe and always show an "Open StikDebug" button. Then `LSApplicationQueriesSchemes ["stikdebug"]` goes too.
- Native tab bar vs custom RN tab bar. The Duo article only vertical-izes system bars. A launcher doesn't need it; I'd skip it.
- `Gow3Pairing.swift:154,173`: optional move to scene activation state.

**P3, verification (needs P0b first).**
- Run Apple's resizability skill (`xcrun agent skills export`, hub Step 1), then test in the resizable iOS simulator, iPhone Mirroring, and the Duo simulator (Xcode 27.1). Apple says the skill misses some issues.
- Fold, unfold and rotate **during gameplay**. Watch the swapchain recreate (`window_ios.mm:153-157`) and `publishSurface` refresh-rate reads when the window changes display.

## Open questions
- CLAUDE.md says "There is no Mac" (CI-only builds), but this machine reports Darwin 27.2. Which is current? It decides whether the Duo simulator is usable, or whether P3 means Mirroring and CI only.
- Is the Duo a target device at all? CLAUDE.md names the iPhone 17.

## Not verified
- A built IPA's real `Info.plist`.
- Behaviour on a Duo simulator or device.
- Press claims about Touch ID and camera unlock, beyond search snippets.
- The GitHub runner labels, beyond the changelog snippet.
- [Transitioning to the UIKit scene-based life cycle], cited from the release notes, not opened.

## Sources
- [Preparing your app for iPhone Duo](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo)
- [Duo hub: Prepare your app](https://developer.apple.com/iphone-duo/prepare/)
- [TN3187](https://developer.apple.com/documentation/technotes/tn3187-migrating-to-the-uikit-scene-based-life-cycle)
- [iOS & iPadOS 27 release notes](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes)
- [UIDesignRequiresCompatibility](https://developer.apple.com/documentation/bundleresources/information-property-list/uidesignrequirescompatibility)
- [UIRequiresFullScreen](https://developer.apple.com/documentation/bundleresources/information-property-list/uirequiresfullscreen)
- [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)
- [Transitioning to the UIKit scene-based life cycle](https://developer.apple.com/documentation/uikit/transitioning-to-the-uikit-scene-based-life-cycle)
- [GitHub: Xcode 27 runner image GA](https://github.blog/changelog/2026-10-15-xcode-27-runner-image-generally-available)
- [MacRumors](https://macrumors.com/2026/09/10/apple-great-mac-feature-for-iphone-duo), [Gizmodo](https://gizmodo.com/iphone-duo-face-recognition-face-id-2000840590), [Tom's Guide](https://tomsguide.com/phones/iphones/iphone-duo-gets-facial-unlock-thanks-to-ios-27-3-beta-but-its-not-full-face-id-heres-everything-you-need-to-know)
