//
//  MainViewController.m
//  Emerald Orrery
//
//  Created by Bill Arnett on 3/15/2010.
//  Copyright Emerald Sequoia LLC 2010. All rights reserved.
//

#import "MainViewController.h"
#import "EOBaseView.h"
#import "EOHandView.h"
#import "OrreryAppDelegate.h"
#import "EOClock.h"
#import "ESAstronomy.hpp"
#import "EOHandView.h"
#import "EOBaseView.h"
#import "Utilities.h"
#undef ECTRACE
#import "ECTrace.h"

@implementation MainViewController

@synthesize baseView;


- (void)viewDidLoad {
    traceEnter("viewDidLoad");
    [super viewDidLoad];
    baseView.autoresizingMask = UIViewAutoresizingNone;  // scaleBaseViewToSize: sizes it instead
    // Running on a Mac, the info button's template image isn't drawn when the view first appears (only after the
    // Options screen has been presented and dismissed), so give it an image that already has its color
    UIImage *infoImage = [[UIImage systemImageNamed:@"info.circle"] imageWithTintColor:[UIColor systemBlueColor]
                                                                         renderingMode:UIImageRenderingModeAlwaysOriginal];
    [infoButton1 setImage:infoImage forState:UIControlStateNormal];
    [baseView setOrientation:[self interfaceOrientation]];
    [Utilities setNewOrientation:[self interfaceOrientation]];
    [[EOClock theClock] clockSetup:baseView orientation:[self interfaceOrientation]];
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.extendedLayoutIncludesOpaqueBars = NO;
    printf("viewDidLoad Button 1 position %f %f\n", infoButton1.frame.origin.x, infoButton1.frame.origin.y);
    printf("viewDidLoad Button 2 position %f %f\n", infoButton2.frame.origin.x, infoButton2.frame.origin.y);
    traceExit ("viewDidLoad");
}

- (void)flipsideViewControllerDidFinish:(FlipsideViewController *)controller {
    traceEnter("flipsideViewControllerDidFinish");
    [EOClock theClock].finishingHelp = true;        // so we don't turn off the status bar too soon if there was a rotation during Help mode
    [[EOClock theClock] setStatusBar:nil];
    [EOClock theClock].dateLabel.hidden = true;
    [self dismissViewControllerAnimated:YES completion:NULL];
    [baseView setNeedsDisplay];
    traceExit ("flipsideViewControllerDidFinish");
}


- (void)viewWillAppear:(BOOL)animated {
    traceEnter("viewWillAppear");
    UIInterfaceOrientation interfaceOrientation = [self interfaceOrientation];
    [baseView setOrientation:interfaceOrientation];
    if (UIInterfaceOrientationIsLandscape(interfaceOrientation)) {
	[(id)baseView setNeedsDisplay];
    }
    [Utilities setNewOrientation:interfaceOrientation];
    CGSize newSize = [self scaleBaseViewToSize:self.view.bounds.size orientation:interfaceOrientation];
    [[EOClock theClock] resetAfterOrientationChangeToOrientation:interfaceOrientation newSize:newSize];
    traceExit ("viewWillAppear");
}

- (void)viewDidAppear:(BOOL)animated {
    traceEnter("viewDidAppear");
    [[EOClock theClock] setStatusBar:nil];
    [EOClock theClock].dateLabel.hidden = ![EOClock theClock].setMode;
    [super viewDidAppear:animated];
    traceExit ("viewDidAppear");
}

-(void)setStatusBarHidden:(bool)newHidden {
    statusBarHidden = newHidden;
    [self setNeedsStatusBarAppearanceUpdate];
}

-(bool)statusBarHidden {
    return statusBarHidden;
}

-(UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (BOOL)prefersStatusBarHidden {
    return statusBarHidden;
}

- (IBAction)showInfo {    
    traceEnter("showInfo");
    NSString *nibName;
    nibName = @"FlipsideView-iPad";

    FlipsideViewController *controller = [[FlipsideViewController alloc] initWithNibName:nibName bundle:nil];
    controller.delegate = self;

    controller.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    controller.modalPresentationStyle = UIModalPresentationFullScreen;  // iOS 13 and later would otherwise use an inset sheet, which clips this layout
    self.statusBarHidden = NO;  // Not [UIApplication setStatusBarHidden:], which is a no-op as of iOS 27
    [self presentViewController:controller animated:YES completion:NULL];
    
    [controller release];
    traceExit ("showInfo");
}


- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    // [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc. that aren't in use.
}


 - (UIInterfaceOrientationMask) supportedInterfaceOrientations {
     return UIInterfaceOrientationMaskAll;
 }

static bool sizeIsPortrait(CGSize size) {
    return size.width < size.height;
}

static UIInterfaceOrientation interfaceOrientationForSize(CGSize size) {
    if (sizeIsPortrait(size)) {
        return UIInterfaceOrientationPortrait;
    } else {
        return UIInterfaceOrientationLandscapeLeft;
    }
}

static void setContentScaleFactor(UIView *view, CGFloat contentScaleFactor) {
    if (view.contentScaleFactor != contentScaleFactor) {
        view.contentScaleFactor = contentScaleFactor;
        [view setNeedsDisplay];
    }
    for (UIView *subview in view.subviews) {
        setContentScaleFactor(subview, contentScaleFactor);
    }
}

// EOClock lays the clock out on a fixed canvas (EOSCREENWIDTH x EOSCREENHEIGHT, turned sideways in landscape), so on
// a larger window it would sit in the middle surrounded by black.  Instead scale baseView up (or down) so the canvas
// fills the safe area (clear of the status bar and home indicator), and return baseView's size in canvas units, which is
// what EOClock should lay out in.
- (CGSize)scaleBaseViewToSize:(CGSize)size orientation:(UIInterfaceOrientation)orientation {
    bool landscape = UIInterfaceOrientationIsLandscape(orientation);
    CGFloat canvasWidth  = landscape ? EOSCREENHEIGHT : EOSCREENWIDTH;
    CGFloat canvasHeight = landscape ? EOSCREENWIDTH  : EOSCREENHEIGHT;
    UIEdgeInsets safeArea = self.view.safeAreaInsets;
    // Set mode (and screen mirroring) hide the status bar, which shrinks the top inset; keep the room the status bar
    // took so the clock doesn't grow while it's hidden.  (A visible status bar can briefly report 0 while it reappears.)
    if (!statusBarHidden && safeArea.top > 0) {
        statusBarSafeAreaTop = safeArea.top;
    }
    safeArea.top = MAX(safeArea.top, statusBarSafeAreaTop);
    CGFloat safeWidth  = size.width  - safeArea.left - safeArea.right;
    CGFloat safeHeight = size.height - safeArea.top  - safeArea.bottom;
    CGFloat scale = MIN(safeWidth / canvasWidth, safeHeight / canvasHeight);
    if (!(scale > 0)) {  // not laid out yet
        scale = 1;
    }
    // Round up to even sizes so the center is on a whole point, as it is for an unscaled window.  Otherwise square
    // views like EOEclipseView round out to non-square frames (and assert).  Rounding up rather than down means any
    // leftover fraction hangs off the edge of the window rather than leaving a sliver of black.
    CGSize canvasSize = CGSizeMake(2 * ceil(size.width / scale / 2), 2 * ceil(size.height / scale / 2));
    // baseView still covers the whole window, but EOClock centers the clock in baseView, so shift baseView's contents
    // to put that center in the middle of the safe area instead.  Whole canvas units, for the same reason as above.
    CGFloat shiftX = round((safeArea.left - safeArea.right) / 2 / scale);
    CGFloat shiftY = round((safeArea.top - safeArea.bottom) / 2 / scale);
    baseView.transform = CGAffineTransformIdentity;
    baseView.bounds = CGRectMake(-shiftX, -shiftY, canvasSize.width, canvasSize.height);
    baseView.center = CGPointMake(size.width / 2, size.height / 2);
    baseView.transform = CGAffineTransformMakeScale(scale, scale);

    // Render at the scaled-up resolution rather than stretching the normal-resolution drawing
    CGFloat displayScale = self.traitCollection.displayScale;
    if (!(displayScale > 0)) {
        displayScale = [UIScreen mainScreen].scale;
    }
    setContentScaleFactor(baseView, displayScale * scale);

    lastLayoutSize = size;
    lastLayoutSafeArea = self.view.safeAreaInsets;  // as reported, for viewDidLayoutSubviews to compare against
    return canvasSize;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    // Resizing a window (on a Mac or in iPadOS windowing) doesn't necessarily come through viewWillTransitionToSize:
    if (!CGSizeEqualToSize(self.view.bounds.size, lastLayoutSize) ||
        !UIEdgeInsetsEqualToEdgeInsets(self.view.safeAreaInsets, lastLayoutSafeArea)) {
        UIInterfaceOrientation newOrientation = interfaceOrientationForSize(self.view.bounds.size);
        [baseView setOrientation:newOrientation];
        [(id)baseView setNeedsDisplay];
        [Utilities setNewOrientation:newOrientation];
        [self updateLayoutAfterRotationToSize:self.view.bounds.size];
    }
}

- (void) updateLayoutAfterRotationToSize:(CGSize)size {
    traceEnter("updateLayoutAfterRotationToSize");
    UIInterfaceOrientation newOrientation = interfaceOrientationForSize(size);
    CGSize canvasSize = [self scaleBaseViewToSize:size orientation:newOrientation];
    [[EOClock theClock] resetAfterOrientationChangeToOrientation:newOrientation newSize:canvasSize];
    //printf("updateLayoutAfterRotationToSize Button 1 position %f %f\n", infoButton1.frame.origin.x, infoButton1.frame.origin.y);
    //printf("updateLayoutAfterRotationToSize Button 2 position %f %f\n", infoButton2.frame.origin.x, infoButton2.frame.origin.y);
    traceExit("updateLayoutAfterRotationToSize");
}

- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    traceEnter("willTransitionToSize");
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    //printf("Current bounds %f %f\n", self.view.bounds.size.width, self.view.bounds.size.height);
    //printf("Current frame %f %f\n", self.view.frame.size.width, self.view.frame.size.height);
    //printf("Current screen frame size %f %f\n", [UIScreen mainScreen].applicationFrame.size.width, [UIScreen mainScreen].applicationFrame.size.height);
    UIInterfaceOrientation newOrientation = interfaceOrientationForSize(size);
    [[EOClock theClock] prepareToReorient:newOrientation];
    [baseView setOrientation:newOrientation];
    // Tricky logic here:  The redraw of the base view wants to happen first iff we're going from portrait to landscape, to remove the box
    if (sizeIsPortrait(size)) {
        tracePrintf("Apparently transitioning TO portrait, setting callback");
        [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context){
            tracePrintf("callback from viewWillTransitionToSize, setting needs display now");
            [(id)baseView setNeedsDisplay];
        }];
    } else {
        tracePrintf("Apparently transitioning TO landscape, setting needs display immediately");
        [(id)baseView setNeedsDisplay];
    }
    [Utilities setNewOrientation:newOrientation];
    [self updateLayoutAfterRotationToSize:size];
    traceExit ("willTransitionToSize");
}

- (void)viewSafeAreaInsetsDidChange {
    traceEnter("viewSafeAreaInsetsDidChange");
    [super viewSafeAreaInsetsDidChange];
    [self updateLayoutAfterRotationToSize:self.view.frame.size];
    traceExit("viewSafeAreaInsetsDidChange");
}

- (void)dealloc {
    [super dealloc];
}


@end
