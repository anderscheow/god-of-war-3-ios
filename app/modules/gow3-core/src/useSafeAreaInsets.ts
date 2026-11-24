import { useEffect, useState } from 'react';
import { AppState, useWindowDimensions } from 'react-native';
import Gow3Core from './Gow3CoreModule';

export type Insets = { top: number; left: number; bottom: number; right: number };

// Shown for the one frame before the native answer arrives: a Dynamic Island iPhone, so the first
// paint does not jump. safeAreaInsets() is new in 0.1.47; an older installed IPA keeps these.
const FIRST_PAINT: Insets = { top: 58, left: 0, bottom: 34, right: 0 };

const same = (a: Insets, b: Insets) => a.top === b.top && a.left === b.left && a.bottom === b.bottom && a.right === b.right;

/** The app window's safe-area insets, read again whenever the window resizes (fold, rotation) or the app returns. */
export function useSafeAreaInsets(): Insets {
  const { width, height } = useWindowDimensions();
  const [insets, setInsets] = useState<Insets>(FIRST_PAINT);
  useEffect(() => {
    if (typeof Gow3Core.safeAreaInsets !== 'function') return;
    let live = true;
    const read = () =>
      Gow3Core.safeAreaInsets()
        .then((next) => live && setInsets((prev) => (same(prev, next) ? prev : next)))
        .catch(() => {});
    read();
    const subscription = AppState.addEventListener('change', (state) => state === 'active' && read());
    return () => {
      live = false;
      subscription.remove();
    };
  }, [width, height]);
  return insets;
}
