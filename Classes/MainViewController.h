//
//  MainViewController.h
//  Emerald Orrery
//
//  Created by Bill Arnett on 3/15/2010.
//  Copyright Emerald Sequoia LLC 2010. All rights reserved.
//

#import "FlipsideViewController.h"

@class EOBaseView;

@interface MainViewController : UIViewController <FlipsideViewControllerDelegate> {
    IBOutlet EOBaseView *baseView;
    IBOutlet UIButton *infoButton1;
    IBOutlet UIButton *infoButton2;
    bool                statusBarHidden;
}

@property(readonly) EOBaseView *baseView;
@property bool statusBarHidden;

- (IBAction)showInfo;

@end
