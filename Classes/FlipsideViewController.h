//
//  FlipsideViewController.h
//  Emerald Orrery
//
//  Created by Bill Arnett on 3/15/2010.
//  Copyright Emerald Sequoia LLC 2010. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol FlipsideViewControllerDelegate;


@interface FlipsideViewController : UIViewController <UITextFieldDelegate, UIPopoverPresentationControllerDelegate> {
    id			    <FlipsideViewControllerDelegate> delegate;
    IBOutlet UIView         *contentView;

    IBOutlet UISwitch	    *alarmSwitch;
    IBOutlet UIButton	    *alarmSetBut;
    IBOutlet UIButton	    *alarmTestBut;
    IBOutlet UINavigationBar *navBar;
    IBOutlet UIButton	    *bottomDoneBut;
    IBOutlet UIButton	    *silenceBut;
    IBOutlet UILabel	    *alarmLabel;
    IBOutlet UILabel	    *alarmValueLabel;
    IBOutlet UITextView	    *helpText;
    IBOutlet UISwitch	    *ULSSwitch;
    IBOutlet UISwitch	    *UNTPSwitch;
    IBOutlet UISwitch	    *totSwitch;
    IBOutlet UISwitch	    *DALaSwitch;
    IBOutlet UISwitch	    *DALbSwitch;
    IBOutlet UITextField    *latField;
    IBOutlet UITextField    *longField;
    IBOutlet UILabel	    *latLabel;
    IBOutlet UILabel	    *longLabel;
    IBOutlet UILabel	    *dateLabel;
    IBOutlet UILabel	    *totTitle;
    IBOutlet UILabel	    *latTitle;
    IBOutlet UILabel	    *longTitle;
    IBOutlet UILabel	    *latlongHelpLabel;
    IBOutlet UILabel	    *ULSTitle;
    IBOutlet UILabel	    *DALTitle;
    IBOutlet UILabel	    *NTPHelp;
    IBOutlet UILabel	    *ULSHelp;
    IBOutlet UILabel	    *totHelp;
    IBOutlet UILabel	    *DALaHelp;
    IBOutlet UILabel	    *DALbHelp;
    IBOutlet UIButton	    *wwwBut;
    IBOutlet UINavigationItem *navItem;
    
    NSTimer		    *updateTimer;
}

@property (nonatomic, assign) id <FlipsideViewControllerDelegate> delegate;
@property (nonatomic, readonly) UISwitch *ULSSwitch;

- (IBAction) alarmSwitchAction: (id) sender;
- (IBAction) alarmSetAction: (id) sender;
- (IBAction) silenceAction: (id) sender;
- (IBAction) alarmTestAction: (id) sender;
- (IBAction) UNTPSwitchAction: (id) sender;
- (IBAction) ULSSwitchAction: (id) sender;
- (IBAction) DALSwitchAction: (id) sender;
- (IBAction) totSwitchAction: (id) sender;
- (IBAction) webAction:(id)sender;
- (IBAction) done;

@end


@protocol FlipsideViewControllerDelegate
- (void)flipsideViewControllerDidFinish:(FlipsideViewController *)controller;
@end

