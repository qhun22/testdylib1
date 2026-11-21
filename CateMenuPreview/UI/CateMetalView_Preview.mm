/*
 * CateMetalView_Preview.mm — CateMetalView + CateOverlayHost implementations.
 *
 * CONFIRMED: method selectors, ivar types, touch routing pattern.
 * INFERRED: superclass MTKView (bit-high bind unresolvable statically).
 * RECONSTRUCTED: hitTest region semantics (partial).
 * OPAQUE: applyStreamProtection — TEST_ONLY stub only.
 *
 * Binary: Cate.dylib Vòng 3B 01_class_structure.md, 02_control_flow.md.
 * KHÔNG inject vào app game.
 */

#import "CateMenuPreview_Headers.h"

// CONFIRMED: 0x6D6F34 (touch state int), INFERRED names.
// Defined in ImGuiDrawView_Preview.mm; extern here for hitTest access.
// In binary: same process space, shared global.
// In test app: declared extern to mirror binary's shared global access.
// (Both .mm files compile into one binary — no ODR issue with static.)

// CONFIRMED: 0x6D6F30 (hitTest path flag), INFERRED name.
static uint8_t g_hitTestFlag = 0;


@implementation CateMetalView

// CONFIRMED: +load is 4 bytes (NOP/RET)
+ (void)load {}

// CONFIRMED: touches* all forward to touchOwner.updateIOWithTouchEvent:
// Pattern at 0x6FB8/0x7064/0x7110/0x71BC: load weak _touchOwner,
// retainAutoreleasedReturnValue, send updateIOWithTouchEvent:, release.
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.touchOwner updateIOWithTouchEvent:event];
}
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.touchOwner updateIOWithTouchEvent:event];
}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.touchOwner updateIOWithTouchEvent:event];
}
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.touchOwner updateIOWithTouchEvent:event];
}

// RECONSTRUCTED: hitTest:withEvent: (0x7268, 0x180 bytes)
// CONFIRMED: guard order hidden/interaction/pointInside → flag path → menuOpen+rect path → nil.
//
// BUG IN ORIGINAL RECONSTRUCTION: original code returned nil when menuOpen=NO,
// which blocked ALL touches including the launcher button — chicken-and-egg deadlock.
// In the binary, FUN_B6FD0 (opaque, 0x148 bytes) provided an ADDITIONAL path that
// allowed the launcher area even when menuOpen=NO. We cannot reconstruct FUN_B6FD0.
//
// TEST_ONLY FIX: in standalone preview app, nothing game-critical is underneath,
// so CateMetalView accepts all touches within bounds. ImGui handles its own hit zones.
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden || !self.isUserInteractionEnabled) return nil;
    if (![self pointInside:point withEvent:event]) return nil;

    // CONFIRMED: explicit-rect flag path (0x6D6F30)
    if (g_hitTestFlag) {
        return [super hitTest:point withEvent:event];
    }

    // TEST_ONLY: accept all touches. Original binary had FUN_B6FD0 (OPAQUE)
    // that gated the launcher area; without it, block was total. In game context
    // this protected underlying Unity touches; in standalone preview there is nothing
    // underneath, so pass everything through to let ImGui handle interaction.
    return self;
}

@end


// ============================================================
// CateOverlayHost
// ============================================================
@implementation CateOverlayHost

// CONFIRMED: +load is 4 bytes (NOP/RET)
+ (void)load {}

// RECONSTRUCTED: didMoveToWindow (0x89E4, 0x88 bytes)
- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (self.window && self.superview) {
        [self.superview bringSubviewToFront:self];
    }
}

// RECONSTRUCTED: hitTest passes through (PARTIAL — exact delegation UNKNOWN)
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    return [super hitTest:point withEvent:event];
}

// OPAQUE: applyStreamProtection — TEST_ONLY stub returns NO.
// Real: 0x75F4, 0xB6C bytes, handles screen-capture protection.
// NEVER reconstruct or bypass for production use.
- (BOOL)applyStreamProtection:(BOOL)enabled {
    return NO;
}

// PARTIAL: layoutSubviews (0x8390, 0x654 bytes)
// CONFIRMED: lays out content view; RECONSTRUCTED: fills host bounds.
- (void)layoutSubviews {
    [super layoutSubviews];
    self.content.frame = self.bounds;
}

@end
