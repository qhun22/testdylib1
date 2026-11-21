/*
 * ImGuiDrawView_Preview.mm — ImGuiDrawView implementation for CateMenuPreview.
 *
 * CONFIRMED: method order, ivar ownership, Metal/MTK setup, observer selectors,
 *            frame structure, touch routing, background/active, dealloc.
 * RECONSTRUCTED: loadView host/overlay alloc, viewDidLoad full sequence.
 * OPAQUE: FUN_2236E0 (gate) → TEST_ONLY stub CateGateStub() returns 1.
 * OPAQUE: FUN_B712C (game payload) → TEST_ONLY ImGui placeholder.
 *
 * Uses Dear ImGui open-source (API-compatible with embedded "1.83 WIP").
 * Metal backend: imgui_impl_metal.h — NOT imgui_impl_osx.h.
 *
 * Binary: Cate.dylib Vòng 3A C02-C05, Vòng 3B 02_control_flow.md, 04_helper_analysis.md.
 * KHÔNG inject vào app game.
 */

#import "CateMenuPreview_Headers.h"
#import "imgui.h"
#import "imgui_impl_metal.h"
#import <os/log.h>

static os_log_t sLog = nil;
static void CateLog(const char *fmt, ...) NS_FORMAT_FUNCTION(1,2);
static void CateLog(const char *fmt, ...) {
    if (!sLog) sLog = os_log_create("com.qhun22.cateprev", "touch");
    va_list ap; va_start(ap, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:@(fmt) arguments:ap];
    va_end(ap);
    os_log(sLog, "%{public}@", msg);
}

// ============================================================
// File-scope statics — MUST be declared before @implementation
// ============================================================

// CONFIRMED: singleton global at 0x710C40 (menuOpen byte)
static uint8_t g_menuOpen_710C40 = 0;

// CONFIRMED: global float at 0x6D6F50 (cateHeroTexture aspect ratio)
static float g_heroAspect = 1.0f;

// CONFIRMED: global pointer at 0x6D6F48 (raw hero texture, non-ARC)
static id<MTLTexture> g_heroTexture = nil;

// Touch state struct — mirrors binary globals 0x6D6F34/38 + local fields.
// MUST be declared before @implementation so methods can reference it.
static struct {
    int      state;        // 0=idle 1=candidate 2=horiz 3=vert 4=release_pending
    uint64_t touchID;
    CGPoint  downPos;
    CGPoint  currentPos;
    CGPoint  lastPublished;
    uint8_t  flag3C;
    uint8_t  flag3D;
} sCateTouch_preview;

// Debug counters (HUD + console)
static uint32_t g_dbg_touchReceived  = 0;
static uint32_t g_dbg_touchBegan     = 0;
static uint32_t g_dbg_clickFired     = 0;
static uint32_t g_dbg_frameCount     = 0;
static CGPoint  g_dbg_lastTouchPos   = {0, 0};

// Launcher position (TEST_ONLY: CONFIRMED 48×48, screen-clamped)
static CGPoint sLauncherPos = {16.0f, 100.0f};

// TEST_ONLY: singleton holder
ImGuiDrawView * _Nullable g_TestImGuiDrawView = nil;


// ============================================================
@implementation ImGuiDrawView
// ============================================================

// CONFIRMED: +load is 4 bytes (NOP/RET)
+ (void)load {}

// CONFIRMED: initWithNibName:bundle: (0x90E4, 0x588 bytes)
// Order: main-thread → gate → super → device → commandQueue → abort-if-nil →
//        ImGui context → library backend → Metal backend → texture load → return self.
- (instancetype)initWithNibName:(NSString *)nib bundle:(NSBundle *)bundle {
    if (!NSThread.isMainThread) return nil;
    if (!(CateGateStub() & 1)) return nil;

    self = [super initWithNibName:nib bundle:bundle];
    if (!self) return nil;

    _device = MTLCreateSystemDefaultDevice();
    _commandQueue = [_device newCommandQueue];

    // CONFIRMED: abort() if no device
    if (!_device) {
        NSLog(@"[CateMenuPreview] MTLCreateSystemDefaultDevice nil — abort");
        abort();
    }

    // CONFIRMED: ImGui context init ("1.83 WIP" version string in binary)
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();

    // CONFIRMED: Metal backend init (FUN_2DF740 → _device)
    ImGui_ImplMetal_Init(_device);

    // CONFIRMED: IO tweaks
    ImGuiIO &io = ImGui::GetIO();
    io.IniFilename = NULL;                   // CONFIRMED: NULL written at g_io+0x18
    ImGui::GetStyle().WindowRounding = 0.0f; // CONFIRMED: style field +0x70

    // HOLES: embedded font data (0x435114/0x640084) — TEST_ONLY uses default font
    io.Fonts->AddFontDefault();

    // CONFIRMED: hero texture load attempted; TEST_ONLY: skip (asset identity UNKNOWN)
    _cateHeroTexture = nil;
    g_heroTexture = nil;
    g_heroAspect = 1.0f;

    return self;
}

// CONFIRMED: mtkView (0x966C, 0xC bytes) — tail call selector overlayView
- (CateMetalView *)mtkView {
    return self.overlayView;
}

// CONFIRMED: loadView (0x9678, 0x444 bytes)
- (void)loadView {
    if (!(CateGateStub() & 1)) {
        self.view = [UIView new];
        self.view.hidden = YES;
        return;
    }

    // CONFIRMED: bounds from keyWindow rootViewController; fallback UIScreen
    CGRect r = UIApplication.sharedApplication.keyWindow
                   .rootViewController.view.bounds;
    if (CGRectIsEmpty(r)) r = UIScreen.mainScreen.bounds;

    CateOverlayHost *host = [[CateOverlayHost alloc] initWithFrame:r];
    host.opaque = NO;
    host.backgroundColor = UIColor.clearColor;
    host.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                            UIViewAutoresizingFlexibleHeight; // 0x12

    self.overlayView = [[CateMetalView alloc] initWithFrame:host.bounds];
    self.overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                        UIViewAutoresizingFlexibleHeight;
    self.overlayView.touchOwner = self;  // CONFIRMED: weak store

    host.content = self.overlayView;
    [host addSubview:self.overlayView]; // CONFIRMED
    self.view = host;                   // CONFIRMED

    // CONFIRMED: NSUserDefaults @"CateStreamMode"
    BOOL streamMode = [NSUserDefaults.standardUserDefaults
                           boolForKey:@"CateStreamMode"];
    [host applyStreamProtection:streamMode]; // TEST_ONLY stub returns NO
}

// CONFIRMED: viewDidLoad (0x9ABC, 0x38C bytes)
- (void)viewDidLoad {
    [super viewDidLoad];

    if (!(CateGateStub() & 1)) return;
    if (!self.device) return;
    if (!ImGui::GetCurrentContext()) return;

    CateMetalView *metalView = self.mtkView;
    metalView.device    = self.device;
    metalView.delegate  = self;
    metalView.clearColor       = MTLClearColorMake(0, 0, 0, 0); // CONFIRMED
    metalView.backgroundColor  = UIColor.clearColor;
    metalView.clipsToBounds    = YES;
    metalView.opaque           = NO;
    metalView.preferredFramesPerSecond = 30; // CONFIRMED: start at 30 FPS

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(cateDidBackground:)
               name:UIApplicationDidEnterBackgroundNotification
             object:nil];
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(cateDidBecomeActive:)
               name:UIApplicationDidBecomeActiveNotification
             object:nil];

    metalView.menuOpen = (BOOL)g_menuOpen_710C40; // CONFIRMED sync
    // CONFIRMED: FUN_B571C → one-time dispatch_async (TEST_ONLY: skip)
}

// CONFIRMED: cateApplyStreamMode (0x9E48, 0xEC) — OPAQUE, not reconstructed
- (void)cateApplyStreamMode {}

// CONFIRMED: cateDidBackground: (0x9F34, 0xCC)
- (void)cateDidBackground:(NSNotification *)note {
    self.menuTouch = nil;
    memset(&sCateTouch_preview, 0, sizeof(sCateTouch_preview));
    [self.mtkView setPaused:YES];
}

// CONFIRMED: cateDidBecomeActive: (0xA000, 0x78)
- (void)cateDidBecomeActive:(NSNotification *)note {
    [self.mtkView setPaused:NO];
    [self cateApplyStreamMode];
}

// CONFIRMED: dealloc (0xA078, 0xB8)
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    ImGui_ImplMetal_Shutdown();
    ImGui::DestroyContext();
}

// CONFIRMED: updateIOWithTouchEvent: (0xA140, 0x67C bytes)
- (void)updateIOWithTouchEvent:(UIEvent *)event {
    g_dbg_touchReceived++;
    if (!(CateGateStub() & 1)) return;
    if (!ImGui::GetCurrentContext()) return;

    // CONFIRMED: count active touches (phase != ended && != cancelled)
    NSUInteger activeCount = 0;
    for (UITouch *t in event.allTouches) {
        if (t.phase != UITouchPhaseEnded && t.phase != UITouchPhaseCancelled)
            activeCount++;
    }

    // CONFIRMED: >= 2 active → reset, clear menuTouch
    if (activeCount >= 2) {
        self.menuTouch = nil;
        memset(&sCateTouch_preview, 0, sizeof(sCateTouch_preview));
        ImGuiIO &io = ImGui::GetIO();
        io.AddMouseButtonEvent(0, false);
        return;
    }

    // CONFIRMED: if no tracked touch, pick first began on mtkView
    UITouch *t = self.menuTouch;
    if (!t) {
        for (UITouch *candidate in event.allTouches) {
            if (candidate.view == self.mtkView &&
                candidate.phase == UITouchPhaseBegan) {
                t = candidate;
                self.menuTouch = t;
                break;
            }
        }
    }

    if (!t || t.view != self.mtkView) return;

    CGPoint p = [t locationInView:self.mtkView]; // CONFIRMED

    ImGuiIO &io = ImGui::GetIO();

    // CONFIRMED: phase switch (raw values confirmed from binary)
    switch (t.phase) {
        case UITouchPhaseBegan:   // 0
            sCateTouch_preview.downPos    = p;
            sCateTouch_preview.currentPos = p;
            sCateTouch_preview.state      = 1; // candidate
            g_dbg_touchBegan++;
            g_dbg_lastTouchPos = p;
            CateLog("touch began (%.0f,%.0f) total=%u", p.x, p.y, g_dbg_touchBegan);
            io.AddMousePosEvent(p.x, p.y);
            io.AddMouseButtonEvent(0, true);
            break;
        case UITouchPhaseMoved:   // 1
            [self _handleMovement:p];
            io.AddMousePosEvent(p.x, p.y);
            break;
        case UITouchPhaseEnded:   // 3
            [self _handleEnded:p];
            io.AddMouseButtonEvent(0, false);
            break;
        case UITouchPhaseCancelled: // 4
            self.menuTouch = nil;
            memset(&sCateTouch_preview, 0, sizeof(sCateTouch_preview));
            io.AddMouseButtonEvent(0, false);
            break;
        default:
            break;
    }

    // CONFIRMED: end/cancel clears weak property
    if (t.phase == UITouchPhaseEnded || t.phase == UITouchPhaseCancelled)
        self.menuTouch = nil;
}

// CONFIRMED: drawInMTKView: (0xAA6C, 0xB1C bytes)
- (void)drawInMTKView:(MTKView *)view {
    if (!NSThread.isMainThread) return;
    if (!self.device) return;
    if (!ImGui::GetCurrentContext()) return;

    // CONFIRMED: gate false → reset state; hadOverlayContent → clear frame
    if (!(CateGateStub() & 1)) {
        self.menuTouch = nil;
        g_menuOpen_710C40 = 0;
        self.mtkView.menuOpen = NO;
        if (!self.hadOverlayContent) return;
        id<MTLCommandBuffer> clearBuf = [self.commandQueue commandBuffer];
        MTLRenderPassDescriptor *clearPass =
            [MTLRenderPassDescriptor renderPassDescriptor];
        clearPass.colorAttachments[0].texture    = view.currentDrawable.texture;
        clearPass.colorAttachments[0].loadAction = MTLLoadActionClear;
        clearPass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);
        id<MTLRenderCommandEncoder> enc =
            [clearBuf renderCommandEncoderWithDescriptor:clearPass];
        [enc endEncoding];
        [clearBuf presentDrawable:view.currentDrawable];
        self.hadOverlayContent = NO;
        [clearBuf commit];
        return;
    }

    // CONFIRMED: display size / scale / delta-time
    CGSize sz    = view.drawableSize;
    CGFloat scale = view.contentScaleFactor;
    if (scale <= 0) scale = UIScreen.mainScreen.scale;

    static CFAbsoluteTime sLastTime = 0;
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    float dt;
    if (sLastTime <= 0) dt = 1.0f / 30.0f;
    else dt = (float)fminf(fmaxf((float)(now - sLastTime), 0.001f), 0.1f);
    sLastTime = now;

    // CONFIRMED: FPS toggle (30 idle, 60 open)
    view.preferredFramesPerSecond = g_menuOpen_710C40 ? 60 : 30;
    self.mtkView.menuOpen = (BOOL)g_menuOpen_710C40;

    ImGuiIO &io = ImGui::GetIO();
    io.DisplaySize            = ImVec2((float)(sz.width  / scale),
                                       (float)(sz.height / scale));
    io.DisplayFramebufferScale = ImVec2((float)scale, (float)scale);
    io.DeltaTime              = dt;

    id<MTLCommandBuffer>       commandBuffer = [self.commandQueue commandBuffer];
    MTLRenderPassDescriptor   *renderPass    = view.currentRenderPassDescriptor;

    if (renderPass) {
        g_dbg_frameCount++;
        ImGui_ImplMetal_NewFrame(renderPass); // CONFIRMED: FUN_2DF8FC equivalent
        ImGui::NewFrame();                    // CONFIRMED: FUN_2889FC

        [self _drawTestMenuPayload];          // TEST_ONLY (replaces opaque FUN_B712C)
        [self _drawDebugHUD];                 // TEST_ONLY: touch/state diagnostics
        [self _drawLauncher:CGSizeMake((float)(sz.width  / scale),
                                       (float)(sz.height / scale))];

        ImGui::Render();                      // CONFIRMED: FUN_28F90C

        id<MTLRenderCommandEncoder> encoder =
            [commandBuffer renderCommandEncoderWithDescriptor:renderPass];
        [encoder pushDebugGroup:@"CateMenuPreview"];
        ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(),
                                       commandBuffer, encoder);
        [encoder popDebugGroup];
        [encoder endEncoding];
    }

    if (view.currentDrawable)
        [commandBuffer presentDrawable:view.currentDrawable]; // CONFIRMED
    self.hadOverlayContent = YES; // CONFIRMED
    [commandBuffer commit];       // CONFIRMED
}

// CONFIRMED: NOP in original binary (0xBC3C, 4 bytes)
- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {}


// ============================================================
// RECONSTRUCTED touch helpers (Vòng 3B §Touch)
// ============================================================

// RECONSTRUCTED from helper A7BC
// CONFIRMED: threshold = max(io_field_0x30, 8); dy>=dx → state3; dx>dy → state2
- (void)_handleMovement:(CGPoint)p {
    float dx = fabsf(p.x - sCateTouch_preview.downPos.x);
    float dy = fabsf(p.y - sCateTouch_preview.downPos.y);
    float threshold = 8.0f; // TEST_ONLY: binary uses max(io.field_0x30, 8)
    if (dy >= dx && dy >= threshold)
        sCateTouch_preview.state = 3;
    else if (dx > dy && dx >= threshold)
        sCateTouch_preview.state = 2;
    sCateTouch_preview.currentPos = p;
}

// RECONSTRUCTED from helper A958
- (void)_handleEnded:(CGPoint)p {
    [self _handleMovement:p];
    if (sCateTouch_preview.state == 1) {
        // CONFIRMED: tap-like transition → toggle menuOpen
        g_menuOpen_710C40 = !g_menuOpen_710C40;
        self.mtkView.menuOpen = (BOOL)g_menuOpen_710C40;
    }
    sCateTouch_preview.state = 4; // release_pending
}


// ============================================================
// TEST_ONLY helpers
// ============================================================

// Placeholder menu (replaces opaque FUN_B712C game payload)
- (void)_drawTestMenuPayload {
    if (!g_menuOpen_710C40) return;

    // CONFIRMED layout from binary: width=clamp(viewW-32,200,850), height=clamp(viewH-36,180,340)
    ImGuiIO &io = ImGui::GetIO();
    float w = fminf(fmaxf(io.DisplaySize.x - 32.0f, 200.0f), 850.0f);
    float h = fminf(fmaxf(io.DisplaySize.y - 36.0f, 180.0f), 340.0f);
    float x = (io.DisplaySize.x - w) * 0.5f;
    float y = (io.DisplaySize.y - h) * 0.5f;

    ImGui::SetNextWindowPos(ImVec2(x, y), ImGuiCond_Always);
    ImGui::SetNextWindowSize(ImVec2(w, h), ImGuiCond_Always);
    ImGui::Begin("##CateMenu", nullptr,
        ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize |
        ImGuiWindowFlags_NoMove     | ImGuiWindowFlags_NoBringToFrontOnFocus);

    ImGui::TextDisabled("[ MENU CONTENT PLACEHOLDER ]");
    ImGui::TextDisabled("FUN_B712C (game features) is OPAQUE");
    ImGui::Separator();
    ImGui::Text("menuOpen: %s",   g_menuOpen_710C40 ? "YES" : "NO");
    ImGui::Text("FPS target: %d", g_menuOpen_710C40 ? 60 : 30);
    ImGui::Text("ImGui: %s",      IMGUI_VERSION);
    ImGui::End();
}

// TEST_ONLY: debug HUD — top-right corner, shows touch/render diagnostics.
// Remove or ifdef-out for production builds.
- (void)_drawDebugHUD {
    ImGuiIO &io = ImGui::GetIO();
    float hudW = 220.0f;
    float hudH = 110.0f;
    ImGui::SetNextWindowPos(ImVec2(io.DisplaySize.x - hudW - 4.0f, 4.0f),
                            ImGuiCond_Always);
    ImGui::SetNextWindowSize(ImVec2(hudW, hudH), ImGuiCond_Always);
    ImGui::SetNextWindowBgAlpha(0.75f);
    ImGui::Begin("##DBG", nullptr,
        ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize |
        ImGuiWindowFlags_NoMove     | ImGuiWindowFlags_NoNav   |
        ImGuiWindowFlags_NoBringToFrontOnFocus);

    ImGui::TextColored(ImVec4(1,1,0,1), "DEBUG HUD");
    ImGui::Text("frame:  %u",    g_dbg_frameCount);
    ImGui::Text("touch:  %u rx / %u began",
                g_dbg_touchReceived, g_dbg_touchBegan);
    ImGui::Text("lastXY: (%.0f, %.0f)",
                g_dbg_lastTouchPos.x, g_dbg_lastTouchPos.y);
    ImGui::Text("click:  %u",    g_dbg_clickFired);
    ImGui::Text("open:   %s",    g_menuOpen_710C40 ? "YES" : "NO");

    ImGui::End();
}

// Launcher 48×48 draggable (CONFIRMED size/drag/clamp from PARTIAL FUN_B8B0 analysis)
- (void)_drawLauncher:(CGSize)screenSize {
    ImGui::SetNextWindowPos(ImVec2(sLauncherPos.x, sLauncherPos.y),
                            ImGuiCond_Always);
    ImGui::SetNextWindowSize(ImVec2(48.0f, 48.0f), ImGuiCond_Always);
    ImGui::Begin("##Launcher", nullptr,
        ImGuiWindowFlags_NoTitleBar  | ImGuiWindowFlags_NoResize |
        ImGuiWindowFlags_NoScrollbar | ImGuiWindowFlags_NoBringToFrontOnFocus);

    ImGui::Button("C", ImVec2(44.0f, 44.0f));

    if (ImGui::IsItemActive() &&
        ImGui::IsMouseDragging(ImGuiMouseButton_Left, 0.0f)) {
        ImVec2 delta = ImGui::GetMouseDragDelta(ImGuiMouseButton_Left, 0.0f);
        ImGui::ResetMouseDragDelta(ImGuiMouseButton_Left);
        sLauncherPos.x += delta.x;
        sLauncherPos.y += delta.y;
        // CONFIRMED: screen-clamped (INFERRED exact clamp, safeAreaInsets unknown)
        sLauncherPos.x = fmaxf(0.0f, fminf(sLauncherPos.x,
                                            (float)screenSize.width  - 48.0f));
        sLauncherPos.y = fmaxf(0.0f, fminf(sLauncherPos.y,
                                            (float)screenSize.height - 48.0f));
    } else if (ImGui::IsItemClicked()) {
        g_menuOpen_710C40 = !g_menuOpen_710C40;
        self.mtkView.menuOpen = (BOOL)g_menuOpen_710C40;
        g_dbg_clickFired++;
        CateLog("launcher clicked → menuOpen=%d (click#%u)",
                g_menuOpen_710C40, g_dbg_clickFired);
    }

    ImGui::End();
}

@end


// ============================================================
// TEST_ONLY: CateMenuTestHarness
// ============================================================

ImGuiDrawView * _Nullable CateMenuTestCreate(void) {
    if (!NSThread.isMainThread) {
        NSLog(@"[CateMenuTest] Must call on main thread");
        return nil;
    }
    if (g_TestImGuiDrawView) return g_TestImGuiDrawView;

    ImGuiDrawView *vc = [[ImGuiDrawView alloc] initWithNibName:nil bundle:nil];
    if (!vc) {
        NSLog(@"[CateMenuTest] ImGuiDrawView init failed (gate or no Metal)");
        return nil;
    }
    g_TestImGuiDrawView = vc;
    NSLog(@"[CateMenuTest] Created: %@", vc);
    return vc;
}

void CateMenuTestToggle(void) {
    g_menuOpen_710C40 = !g_menuOpen_710C40;
    g_TestImGuiDrawView.mtkView.menuOpen = (BOOL)g_menuOpen_710C40;
    NSLog(@"[CateMenuTest] menuOpen = %d", g_menuOpen_710C40);
}
