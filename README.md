# CateMenuPreview

Standalone iOS preview app rebuilt from binary analysis of `Cate.dylib`.
Installs on device via **TrollStore** (unsigned IPA).

## What this is

- Reconstructs the ImGui Metal UI from Cate.dylib reverse-engineering
- Uses **Dear ImGui** open-source (API-compatible with embedded "1.83 WIP")
- `FUN_2236E0` gate replaced by `CateGateStub()` → always returns 1
- `FUN_B712C` game payload replaced by placeholder menu
- **Does not** contain Cate.dylib, UnityFramework, or any game binary

## Build (Codemagic)

1. Push repo to `https://github.com/qhun22/testdylib1` (private)
2. Connect repo in [Codemagic](https://codemagic.io)
3. Select workflow **"iOS Unsigned IPA (TrollStore)"**
4. Start build — artifact: `CateMenuPreview_unsigned.ipa`

The build script automatically:
- Installs XcodeGen
- Clones Dear ImGui v1.90.9 into `ThirdParty/imgui/`
- Generates `.xcodeproj` via XcodeGen
- Builds arm64 iOS Release, `CODE_SIGNING_ALLOWED=NO`
- Packages as unsigned IPA

## Install (TrollStore)

1. Download `CateMenuPreview_unsigned.ipa` from Codemagic artifacts
2. Open TrollStore on device → **Install** → select IPA
3. Launch **CateMenuPreview**
4. Tap the **"C"** button (48×48 launcher, draggable) to toggle the ImGui menu

## Local development (macOS required for Xcode)

```bash
# Download ImGui first (Codemagic does this automatically)
mkdir -p ThirdParty
git clone --branch v1.90.9 --depth 1 https://github.com/ocornut/imgui.git ThirdParty/imgui

# Generate Xcode project
brew install xcodegen
xcodegen generate

# Open in Xcode
open CateMenuPreview.xcodeproj
```

## Recovery status

| Component | Status |
|---|---|
| CateMetalView (MTKView) | CONFIRMED ivar/selector/touch routing |
| CateOverlayHost (UIView) | CONFIRMED structure; layoutSubviews RECONSTRUCTED |
| ImGuiDrawView (UIViewController) | CONFIRMED init/loadView/viewDidLoad/draw frame |
| FUN_2236E0 (gate) | OPAQUE → stub returns 1 |
| FUN_B712C (game features) | OPAQUE → placeholder |
| Dear ImGui Metal backend | Open-source replacement (1.90.9) |

## Security

- Binary `Cate.dylib` is **not** in this repository
- Repository must remain **private**
- Do not upload game binaries, global-metadata.dat, or recovery documents
