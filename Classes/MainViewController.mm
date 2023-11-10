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
    CGSize newSize = [UIScreen mainScreen].applicationFrame.size;
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
    [UIApplication sharedApplication].statusBarHidden = NO;
    [self presentViewController:controller animated:YES completion:NULL];
    
    [controller release];
    traceExit ("showInfo");
}


- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    // [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc. that aren't in use.
}


 - (BOOL)shouldAutorotate {
     return YES;
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

- (void) updateLayoutAfterRotationToSize:(CGSize)size {
    traceEnter("updateLayoutAfterRotationToSize");
    UIInterfaceOrientation newOrientation = interfaceOrientationForSize(size);
    [[EOClock theClock] resetAfterOrientationChangeToOrientation:newOrientation newSize:size];
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
