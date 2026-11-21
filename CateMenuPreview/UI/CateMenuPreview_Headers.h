/*
 * CateMenuPreview_Headers.h — Shared interfaces for CateMenuPreview test app.
 *
 * CONFIRMED: class names, method selectors, ivar types from binary metadata.
 * INFERRED: superclasses (bit-high dyld bind records unresolvable statically).
 * TEST_ONLY: CateGateStub() replaces opaque FUN_2236E0.
 *
 * Binary: Cate.dylib SHA-256 b3a85848a00abdbb23fd524b9b9f2b2a607ec1195ebf378cba88cb575b938850
 */

#pragma once

#import <UIKit/UIKit.h>
#import <MetalKit/MetalKit.h>
#import <Metal/Metal.h>

// Forward declare ImGuiDrawView for weak property (CateMetalView.touchOwner)
@class ImGuiDrawView;

// ============================================================
// CateMetalView — MTKView subclass that hosts the ImGui surface
// CONFIRMED: instance_size=56 (8 header + 8 _menuOpen + 8 _touchOwner + 32 _menuFrame)
// INFERRED superclass: MTKView (bit-high bind at class_va 0x6D63B0)
// ============================================================
@interface CateMetalView : MTKView

// CONFIRMED: ivar +0x8 type B (BOOL)
@property (nonatomic) BOOL menuOpen;

// CONFIRMED: ivar +0x10 type @"ImGuiDrawView", W (weak)
@property (nonatomic, weak) ImGuiDrawView *touchOwner;

// CONFIRMED: ivar +0x18 type {CGRect=...} (32 bytes)
@property (nonatomic) CGRect menuFrame;

@end


// ============================================================
// CateOverlayHost — UIView overlay container
// CONFIRMED: instance_size=32 (8 header + 8 content + 8 captureField + 8 captureCanvas)
// INFERRED superclass: UIView
// ============================================================
@interface CateOverlayHost : UIView

// CONFIRMED: ivar +0x8 strong @"CateMetalView"
@property (nonatomic, strong) CateMetalView *content;

// CONFIRMED: ivar +0x10 strong @"UITextField" (captureField)
@property (nonatomic, strong) UITextField *captureField;

// CONFIRMED: ivar +0x18 strong @"UIView" (captureCanvas)
@property (nonatomic, strong) UIView *captureCanvas;

// OPAQUE: applyStreamProtection — 0xB6C bytes, handles screen-capture protection.
// TEST_ONLY stub returns NO. NEVER reconstruct or bypass in production.
- (BOOL)applyStreamProtection:(BOOL)enabled;

@end


// ============================================================
// ImGuiDrawView — UIViewController + MTKViewDelegate, hosts ImGui rendering
// CONFIRMED: instance_size=56 (8 _hadOverlayContent + 8 _device + 8 _commandQueue +
//            8 _overlayView + 8 _cateHeroTexture + 8 _menuTouch)
// INFERRED superclass: UIViewController (bit-high bind at class_va 0x6D64A0)
// ============================================================
@interface ImGuiDrawView : UIViewController <MTKViewDelegate>

// CONFIRMED: ivar +0x8 type B (BOOL)
@property (nonatomic) BOOL hadOverlayContent;

// CONFIRMED: ivar +0x10 strong id<MTLDevice>
@property (nonatomic, strong) id<MTLDevice> device;

// CONFIRMED: ivar +0x18 strong id<MTLCommandQueue>
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;

// CONFIRMED: ivar +0x20 strong @"CateMetalView"
@property (nonatomic, strong) CateMetalView *overlayView;

// CONFIRMED: ivar +0x28 strong id<MTLTexture>
@property (nonatomic, strong) id<MTLTexture> cateHeroTexture;

// CONFIRMED: ivar +0x30 weak @"UITouch"
@property (nonatomic, weak) UITouch *menuTouch;

// CONFIRMED: tail call to self.overlayView (0x966C, 0xC bytes)
- (CateMetalView *)mtkView;

// CONFIRMED: touch routing target from CateMetalView.touches*
- (void)updateIOWithTouchEvent:(UIEvent *)event;

@end


// ============================================================
// TEST_ONLY: Gate stub replaces opaque FUN_2236E0 (0x474 bytes, return type uint32_t)
// Always returns 1 so the preview app always initializes.
// ============================================================
static inline uint32_t CateGateStub(void) { return 1; }

// TEST_ONLY globals and helpers
#ifdef __cplusplus
extern "C" {
#endif
extern ImGuiDrawView * _Nullable g_TestImGuiDrawView;
ImGuiDrawView * _Nullable CateMenuTestCreate(void);
void CateMenuTestToggle(void);
#ifdef __cplusplus
}
#endif
