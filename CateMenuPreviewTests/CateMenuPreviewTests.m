/*
 * CateMenuPreviewTests.m — XCTest suite for CateMenuPreview.
 *
 * Runs against the host app binary (BUNDLE_LOADER).
 * Does NOT run Cate.dylib. Does NOT inject into game app.
 * CONFIRMED = behavior verified from binary evidence.
 * TEST_ONLY = test-harness behavior only, not binary parity.
 */

#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import "CateMenuPreview_Headers.h"


// ============================================================
// T01 — CateMetalView structure (CONFIRMED)
// ============================================================
@interface CateMetalViewStructureTests : XCTestCase @end
@implementation CateMetalViewStructureTests

- (void)test_alloc_init {
    CateMetalView *v = [[CateMetalView alloc]
                            initWithFrame:CGRectMake(0, 0, 100, 100)];
    XCTAssertNotNil(v);
}

- (void)test_menuOpen_toggles {
    CateMetalView *v = [[CateMetalView alloc] initWithFrame:CGRectZero];
    XCTAssertEqual(v.menuOpen, NO);
    v.menuOpen = YES;
    XCTAssertEqual(v.menuOpen, YES);
    v.menuOpen = NO;
    XCTAssertEqual(v.menuOpen, NO);
}

- (void)test_touchOwner_weak_default_nil {
    CateMetalView *v = [[CateMetalView alloc] initWithFrame:CGRectZero];
    XCTAssertNil(v.touchOwner);
}

- (void)test_menuFrame_roundtrip {
    CateMetalView *v = [[CateMetalView alloc] initWithFrame:CGRectZero];
    CGRect r = CGRectMake(10, 20, 300, 200);
    v.menuFrame = r;
    XCTAssertTrue(CGRectEqualToRect(v.menuFrame, r));
}

@end


// ============================================================
// T02 — CateOverlayHost structure (CONFIRMED)
// ============================================================
@interface CateOverlayHostTests : XCTestCase @end
@implementation CateOverlayHostTests

- (void)test_alloc {
    CateOverlayHost *h = [[CateOverlayHost alloc]
                              initWithFrame:CGRectMake(0, 0, 375, 667)];
    XCTAssertNotNil(h);
}

- (void)test_content_property {
    CateOverlayHost *h = [[CateOverlayHost alloc]
                              initWithFrame:CGRectMake(0, 0, 375, 667)];
    XCTAssertNil(h.content);
    CateMetalView *mv = [[CateMetalView alloc] initWithFrame:h.bounds];
    h.content = mv;
    XCTAssertEqual(h.content, mv);
}

- (void)test_applyStreamProtection_stub_returns_NO {
    CateOverlayHost *h = [[CateOverlayHost alloc] initWithFrame:CGRectZero];
    XCTAssertEqual([h applyStreamProtection:YES], NO,
                   @"TEST_ONLY stub must return NO");
}

- (void)test_layoutSubviews_fills_bounds {
    CateOverlayHost *h = [[CateOverlayHost alloc]
                              initWithFrame:CGRectMake(0, 0, 375, 667)];
    CateMetalView *mv  = [[CateMetalView alloc] initWithFrame:CGRectZero];
    h.content = mv;
    [h layoutSubviews];
    XCTAssertTrue(CGRectEqualToRect(mv.frame, h.bounds));
}

@end


// ============================================================
// T03 — ImGuiDrawView Metal init (CONFIRMED)
// ============================================================
@interface ImGuiDrawViewStructureTests : XCTestCase @end
@implementation ImGuiDrawViewStructureTests

- (void)test_requires_main_thread {
    XCTAssertTrue(NSThread.isMainThread);
    if (!MTLCreateSystemDefaultDevice()) { return; }
    ImGuiDrawView *vc = [[ImGuiDrawView alloc] initWithNibName:nil bundle:nil];
    XCTAssertNotNil(vc);
}

- (void)test_mtkView_is_overlayView {
    if (!MTLCreateSystemDefaultDevice()) { return; }
    ImGuiDrawView *vc = [[ImGuiDrawView alloc] initWithNibName:nil bundle:nil];
    if (!vc) return;
    XCTAssertEqual(vc.mtkView, vc.overlayView);
}

- (void)test_device_non_nil {
    if (!MTLCreateSystemDefaultDevice()) { return; }
    ImGuiDrawView *vc = [[ImGuiDrawView alloc] initWithNibName:nil bundle:nil];
    if (!vc) return;
    XCTAssertNotNil(vc.device);
    XCTAssertNotNil(vc.commandQueue);
}

- (void)test_hadOverlayContent_default_NO {
    if (!MTLCreateSystemDefaultDevice()) { return; }
    ImGuiDrawView *vc = [[ImGuiDrawView alloc] initWithNibName:nil bundle:nil];
    if (!vc) return;
    XCTAssertEqual(vc.hadOverlayContent, NO);
}

@end


// ============================================================
// T04 — loadView hierarchy (CONFIRMED)
// ============================================================
@interface LoadViewTests : XCTestCase @end
@implementation LoadViewTests

- (void)test_view_is_CateOverlayHost {
    if (!MTLCreateSystemDefaultDevice()) { return; }
    ImGuiDrawView *vc = [[ImGuiDrawView alloc] initWithNibName:nil bundle:nil];
    if (!vc) return;
    [vc loadViewIfNeeded];
    XCTAssertTrue([vc.view isKindOfClass:[CateOverlayHost class]]);
}

- (void)test_overlayView_is_CateMetalView {
    if (!MTLCreateSystemDefaultDevice()) { return; }
    ImGuiDrawView *vc = [[ImGuiDrawView alloc] initWithNibName:nil bundle:nil];
    if (!vc) return;
    [vc loadViewIfNeeded];
    XCTAssertNotNil(vc.overlayView);
    XCTAssertTrue([vc.overlayView isKindOfClass:[CateMetalView class]]);
}

- (void)test_touchOwner_set_to_self {
    if (!MTLCreateSystemDefaultDevice()) { return; }
    ImGuiDrawView *vc = [[ImGuiDrawView alloc] initWithNibName:nil bundle:nil];
    if (!vc) return;
    [vc loadViewIfNeeded];
    XCTAssertEqual(vc.overlayView.touchOwner, vc);
}

- (void)test_overlayView_is_subview_of_host {
    if (!MTLCreateSystemDefaultDevice()) { return; }
    ImGuiDrawView *vc = [[ImGuiDrawView alloc] initWithNibName:nil bundle:nil];
    if (!vc) return;
    [vc loadViewIfNeeded];
    CateOverlayHost *host = (CateOverlayHost *)vc.view;
    XCTAssertTrue([host.subviews containsObject:vc.overlayView]);
}

- (void)test_host_opaque_NO {
    if (!MTLCreateSystemDefaultDevice()) { return; }
    ImGuiDrawView *vc = [[ImGuiDrawView alloc] initWithNibName:nil bundle:nil];
    if (!vc) return;
    [vc loadViewIfNeeded];
    XCTAssertFalse(vc.view.opaque);
}

@end


// ============================================================
// T05 — viewDidLoad Metal setup (CONFIRMED)
// ============================================================
@interface ViewDidLoadTests : XCTestCase @end
@implementation ViewDidLoadTests

- (void)test_device_propagated_to_metalView {
    if (!MTLCreateSystemDefaultDevice()) { return; }
    ImGuiDrawView *vc = [[ImGuiDrawView alloc] initWithNibName:nil bundle:nil];
    if (!vc) return;
    [vc loadViewIfNeeded];
    [vc viewDidLoad];
    XCTAssertEqual(vc.overlayView.device, vc.device);
}

- (void)test_initial_FPS_30 {
    if (!MTLCreateSystemDefaultDevice()) { return; }
    ImGuiDrawView *vc = [[ImGuiDrawView alloc] initWithNibName:nil bundle:nil];
    if (!vc) return;
    [vc loadViewIfNeeded];
    [vc viewDidLoad];
    XCTAssertEqual(vc.mtkView.preferredFramesPerSecond, 30);
}

@end


// ============================================================
// T06 — Touch routing (CONFIRMED forwarding pattern)
// ============================================================
@interface TouchRoutingTests : XCTestCase @end
@implementation TouchRoutingTests

- (void)test_touchOwner_set_on_overlayView {
    if (!MTLCreateSystemDefaultDevice()) { return; }
    ImGuiDrawView *vc = [[ImGuiDrawView alloc] initWithNibName:nil bundle:nil];
    if (!vc) return;
    [vc loadViewIfNeeded];
    XCTAssertEqual(vc.overlayView.touchOwner, vc);
}

- (void)test_menuOpen_toggle {
    CateMetalView *mv = [[CateMetalView alloc] initWithFrame:CGRectZero];
    XCTAssertEqual(mv.menuOpen, NO);
    mv.menuOpen = YES;
    XCTAssertEqual(mv.menuOpen, YES);
}

@end


// ============================================================
// T07 — TEST_ONLY harness
// ============================================================
@interface TestHarnessTests : XCTestCase @end
@implementation TestHarnessTests

- (void)test_TestCreate_returns_non_nil {
    if (!MTLCreateSystemDefaultDevice()) { return; }
    g_TestImGuiDrawView = nil;
    ImGuiDrawView *vc = CateMenuTestCreate();
    XCTAssertNotNil(vc);
    XCTAssertEqual(g_TestImGuiDrawView, vc);
}

- (void)test_TestCreate_idempotent {
    if (!MTLCreateSystemDefaultDevice()) { return; }
    ImGuiDrawView *a = CateMenuTestCreate();
    ImGuiDrawView *b = CateMenuTestCreate();
    XCTAssertEqual(a, b);
}

- (void)test_TestToggle_flips_menuOpen {
    if (!MTLCreateSystemDefaultDevice()) { return; }
    ImGuiDrawView *vc = CateMenuTestCreate();
    if (!vc) return;
    [vc loadViewIfNeeded];
    BOOL before = vc.mtkView.menuOpen;
    CateMenuTestToggle();
    XCTAssertNotEqual((BOOL)vc.mtkView.menuOpen, before);
}

@end
