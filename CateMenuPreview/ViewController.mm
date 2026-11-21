#import "ViewController.h"
#import "CateMenuPreview_Headers.h"

@implementation ViewController {
    ImGuiDrawView *_menuVC;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;

    // Create CateMenuPreview ImGuiDrawView on main thread.
    // CateMenuTestCreate() uses TEST_ONLY gate stub (always passes).
    _menuVC = CateMenuTestCreate();
    if (!_menuVC) {
        NSLog(@"[ViewController] CateMenuTestCreate failed — no Metal device?");
        return;
    }

    [self addChildViewController:_menuVC];
    _menuVC.view.frame = self.view.bounds;
    _menuVC.view.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_menuVC.view];
    [_menuVC didMoveToParentViewController:self];

    NSLog(@"[ViewController] ImGuiDrawView added. Tap launcher button to toggle menu.");
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

@end
