# App Icon — design source

Source **layers** for the app icon, used as inputs to Apple's **Icon Composer**.
They are NOT compiled into the app — this `design/` folder sits outside the app
target, so nothing here is bundled or shipped. It's version-controlled design
source only.

## Files (1024×1024)
- `ledger-L-foreground.png`    — gold "L", transparent background
- `ledger-background.png`      — warm radial-dark background
- `ledger-bars-foreground.png` — 3 bars (needs / savings / wants), transparent
- `preview-L.png`, `preview-bars.png` — composed references (do not import)

## Workflow
1. In Icon Composer, add `ledger-background.png` as the bottom layer and a
   foreground (`L` or `bars`) on top.
2. Give the foreground a shadow / depth offset for the floating effect; tune the
   glass/specular settings.
3. Export the `.icon` file.
4. **The `.icon` DOES belong in the app target** (unlike these source files):
   add it to the Ledger target in Xcode and set it as the app icon — it
   supersedes `Ledger/Ledger/Assets.xcassets/AppIcon`.

## Palette
Gold `#CBA85A`; categories — needs `#B5734A`, savings `#7F8F6E`, wants `#CBA85A`.
