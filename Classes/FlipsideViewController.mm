//
//  FlipsideViewController.m
//  Emerald Orrery
//
//  Created by Bill Arnett on 3/15/2010.
//  Copyright Emerald Sequoia LLC 2010. All rights reserved.
//

#import "FlipsideViewController.h"
#import "AlarmSetViewController.h"
#import "EOClock.h"
#import "Constants.h"
#import "ECAudio.h"
#import "EOBatteryAndDAL.h"
#import "OrreryAppDelegate.h"

#include "ESTime.hpp"
#include "ESLocation.hpp"
#include "ESTimeLocAstroEnvironment.hpp"
#include "ESWatchTime.hpp"

static double tzOffset;
static NSDateFormatter	*dateFormatter, *alarmTimeFormatter;

@implementation FlipsideViewController

@synthesize delegate, ULSSwitch;

- (void)setLabels {
    ESLocation *location = [[EOClock theClock] env]->location();
    latLabel.text  = [NSString stringWithFormat:@"%.3f", location->latitudeDegrees()];
    longLabel.text = [NSString stringWithFormat:@"%.3f", location->longitudeDegrees()];
    switch (ESTime::currentStatus()) {
      case ESTimeSourceStatusOff:                   // No synchronization is being done
        NTPHelp.text  = @"-";
        break;
      case ESTimeSourceStatusSynchronized:          // We're good
      case ESTimeSourceStatusPollingRefining:       // We were kind of good (failedRefining) and the user has asked for a resync and we're trying
      case ESTimeSourceStatusPollingSynchronized:   // We're good but the user has asked for a resync and we're trying
      case ESTimeSourceStatusFailedSynchronized:    // We were synchronized before but we failed when the user asked for a resync
      case ESTimeSourceStatusRefining:              // We've gotten some packets but they aren't good enough to say we're good
      case ESTimeSourceStatusFailedRefining:        // We got some packets so we're kind of synchronized but not completely good
      case ESTimeSourceStatusNoNetSynchronized:     // We were synchronized before but the net wasn't available when the user asked for a resync
      case ESTimeSourceStatusNoNetRefining:         // We had some packets before but the net wasn't available when we tried to refine
        NTPHelp.text  = [NSString stringWithFormat:@"%0.3f", ESTime::skewForReportingPurposesOnly()];
        break;
      case ESTimeSourceStatusPollingUnsynchronized: // We know nothing but we're trying
      case ESTimeSourceStatusFailedUnynchronized:   // We were unsynchronized before and we failed the last time we tried
      case ESTimeSourceStatusUnsynchronized:        // We know nothing
      case ESTimeSourceStatusNoNetUnsynchronized:   // We were unsynchronized before but the net wasn't available when the user asked for a resync
        NTPHelp.text  = @"x";
        break;
      default:
	    assert(false);
    }
}

- (void)setFieldsAndLabels {
    ESLocation *location = [[EOClock theClock] env]->location();
    latField.text  = [NSString stringWithFormat:@"%.3f", location->latitudeDegrees()];
    longField.text = [NSString stringWithFormat:@"%.3f", location->longitudeDegrees()];
    [self setLabels];
}

- (void)tick {
    dateLabel.text = [dateFormatter stringFromDate:[[EOClock theClock] time]->currentDate()];
    [self setLabels];
}

- (void)setTextAndFontInLabel:(UILabel *)label text:(NSString *)text {
//  [stevep 10/18/2013: None of this sizing was actually used at time of iOS 7 conversion, so just getting rid of method to determine size]
//    UIFont *font = label.font;
//    CGSize labelSize = label.bounds.size;
//    CGFloat actualFontSize;
//    [text sizeWithFont:font minFontSize:label.minimumFontSize actualFontSize:&actualFontSize forWidth:labelSize.width lineBreakMode:UILineBreakModeWordWrap];
    label.text = text;
//    if (actualFontSize != font.pointSize) {
//	label.font = [font fontWithSize:actualFontSize];
//    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    NSString *title = NSLocalizedStringWithDefaultValue(@"CFBundleDisplayName",@"InfoPlist",[NSBundle mainBundle],@"Observatory",@"Name of this application");
#ifndef NDEBUG
    title = [title stringByAppendingFormat:@" - %@",NSLocalizedString(@"language", @"name of this language")];
#endif
    navItem.title = title;
    tzOffset = ESCalendar_tzOffsetForTimeInterval(ESCalendar_localTimeZone(), ESTime::currentTime());
    dateFormatter = [[NSDateFormatter alloc] init];
    alarmTimeFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setTimeStyle:NSDateFormatterFullStyle];
    [dateFormatter setDateStyle:NSDateFormatterFullStyle];
    [alarmTimeFormatter setTimeStyle:NSDateFormatterShortStyle];
    // self.view.backgroundColor = [UIColor blackColor];
    self.view.backgroundColor = [UIColor redColor];
    // helpText.backgroundColor = [UIColor viewFlipsideBackgroundColor];
    self.title = NSLocalizedString(@"Options", @"Title for options settings screen");
    updateTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(tick) userInfo:nil repeats:true];

    // localize here instead of in IB
    alarmLabel.text= NSLocalizedString(@"Alarm:", @"label for enable alarm clock switch");
    [alarmSetBut setTitle:NSLocalizedString(@"Set", @"Set (verb)") forState:UIControlStateNormal];
    alarmSetBut.titleLabel.textAlignment = NSTextAlignmentCenter;
    [alarmTestBut setTitle:NSLocalizedString(@"Test", @"Test alarm") forState:UIControlStateNormal];
    [bottomDoneBut setTitle:NSLocalizedString(@"Done", @"Done") forState:UIControlStateNormal];
    alarmTestBut.titleLabel.textAlignment = NSTextAlignmentCenter;
    alarmValueLabel.text = [alarmTimeFormatter stringFromDate:[EOClock alarmTime]->currentDate()];
    totTitle.text  = NSLocalizedString(@"Noon on Top:", @"name of option for noon on the top of the 24-hour dial (instead of midnight)");
    latTitle.text  = NSLocalizedString(@"Latitude:", @"north-south coordinate");
    longTitle.text = NSLocalizedString(@"Longitude:", @"east-west coordinate");
    ULSTitle.text  = NSLocalizedString(@"Use Location Services:", @"name of option to use the iPhone's location determination features");

    [self setTextAndFontInLabel:ULSHelp text:NSLocalizedString(@"Turn OFF to set location manually", @"Help message for 'Use Location Services'")];
    [self setTextAndFontInLabel:totHelp text:NSLocalizedString(@"Turn ON for noon on top, OFF for midnight on top", @"Help message for 'Noon on Top'")];
    [self setTextAndFontInLabel:DALTitle text:NSLocalizedString(@"Disable Auto-Lock:", @"name of option to turn off the iPhone's automatic screen locking feature")];
    [self setTextAndFontInLabel:DALaHelp text:NSLocalizedString(@"Turn ON to prevent automatic sleep when plugged in", @"Help message for Disable Auto-Lock when plugged in")];
    [self setTextAndFontInLabel:DALbHelp text:NSLocalizedString(@"Turn ON to prevent automatic sleep on battery", @"Help message for Disable Auto-Lock on battery")];
    
    // Don't use setTextAndFontInLabel for the following one; we want the full size text since there's plenty of vertical room
    latlongHelpLabel.text = NSLocalizedString(@"Use a single decimal number for each field; use negative values for south and west.", @"Help message for latitude/longitude entry");
    
    [wwwBut setTitle:NSLocalizedString(@" ... tap to visit our web site",@"label for a WWW link") forState:UIControlStateNormal];
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.extendedLayoutIncludesOpaqueBars = NO;
}

-(UIStatusBarStyle)preferredStatusBarStyle{
    return UIStatusBarStyleLightContent;
}

- (void)viewWillDisappear:(BOOL)animated {
    [updateTimer invalidate];
    updateTimer = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    NSStringEncoding *enc = nil;
    NSString *cpyrt = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"copyright" ofType:@"txt"] usedEncoding:enc error:nil];
    NSString *versn = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"help" ofType:@"txt"] usedEncoding:enc error:nil]; // really just the version string
    helpText.text = [[versn         stringByAppendingString:[[NSBundle mainBundle] localizedStringForKey:@"Help Text0" value:nil table:nil]] stringByAppendingString:@"\n\n"];
    helpText.text = [[helpText.text stringByAppendingString:[[NSBundle mainBundle] localizedStringForKey:@"Help Text1" value:nil table:nil]] stringByAppendingString:@"\n\n"];
    helpText.text = [[helpText.text stringByAppendingString:[[NSBundle mainBundle] localizedStringForKey:@"Help Text1.5" value:nil table:nil]] stringByAppendingString:@"\n\n"];
    helpText.text = [[helpText.text stringByAppendingString:[[NSBundle mainBundle] localizedStringForKey:@"Help Text2" value:nil table:nil]] stringByAppendingString:@"\n\n"];
    helpText.text = [[helpText.text stringByAppendingString:[[NSBundle mainBundle] localizedStringForKey:@"Help Text3" value:nil table:nil]] stringByAppendingString:@"\n\n"];
    helpText.text = [[helpText.text stringByAppendingString:[[NSBundle mainBundle] localizedStringForKey:@"Help Text4" value:nil table:nil]] stringByAppendingString:@"\n\n"];
    helpText.text = [[helpText.text stringByAppendingString:[[NSBundle mainBundle] localizedStringForKey:@"Help Text5" value:nil table:nil]] stringByAppendingString:@"\n\n"];
    helpText.text = [[helpText.text stringByAppendingString:[[NSBundle mainBundle] localizedStringForKey:@"Help Text6" value:nil table:nil]] stringByAppendingString:@"\n\n"];
    helpText.text = [[helpText.text stringByAppendingString:[[NSBundle mainBundle] localizedStringForKey:@"Help Text7" value:nil table:nil]] stringByAppendingString:@"\n\n"];
    helpText.text = [[helpText.text stringByAppendingString:[[NSBundle mainBundle] localizedStringForKey:@"Help Text8" value:nil table:nil]] stringByAppendingString:@"\n\n"];
    helpText.text = [helpText.text stringByAppendingString:cpyrt];
    ULSSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"EOUseLocationServices"];
    DALaSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"EODisableAutoLock"];
    DALbSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"EODisableAutoLockUnplugged"];
    alarmSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"EOAlarmEnabled"];
    UNTPSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"EOUseNTP"];
    totSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"EONoonOnTop"];
    alarmSetBut.hidden = alarmTestBut.hidden = !alarmSwitch.on;
#ifdef NDEBUG
    NTPHelp.hidden = true;
#endif
    [self ULSSwitchAction:nil];
}

- (IBAction)webAction:(id)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://emeraldsequoia.com/"]];
}

- (IBAction)alarmSetAction:(id)sender {
    UIViewController *avc = [[AlarmSetViewController alloc] initWithNibName:@"AlarmSet-iPad" bundle:nil];
    avc.modalPresentationStyle = UIModalPresentationPopover;
    avc.preferredContentSize = CGSizeMake(400.0, 300.0);
    [self presentViewController:avc animated:YES completion:NULL];
    avc.popoverPresentationController.delegate = self;
    avc.popoverPresentationController.sourceView = alarmSetBut;
    avc.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionUp;
    [avc release];
}

static NSTimer *alarmTestButtonTimer = nil;

- (void)revertAlarmTestButton {
    [alarmTestBut setTitle:NSLocalizedString(@"Test", @"Test alarm") forState:UIControlStateNormal];
    alarmTestButtonTimer = nil;
}

- (IBAction)alarmTestAction:(id)sender {
    [alarmTestButtonTimer invalidate];
    alarmTestButtonTimer = nil;
    if ([ECAudio ringing]) {
	[self revertAlarmTestButton];
	[ECAudio stopRinging];
    } else {
	[alarmTestBut setTitle:NSLocalizedString(@"Stop", @"Stop alarm test") forState:UIControlStateNormal];
	int testRings = 10;
	int ringInterval = 2; // seconds
	[ECAudio startRinging:testRings];
	alarmTestButtonTimer = [NSTimer scheduledTimerWithTimeInterval:(testRings*ringInterval) target:self selector:@selector(revertAlarmTestButton) userInfo:nil repeats:false];
    }
}

- (IBAction)alarmSwitchAction:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:alarmSwitch.on forKey:@"EOAlarmEnabled"];
    bool hideIt = !alarmSwitch.on;
    alarmSetBut.hidden = hideIt;
    alarmTestBut.hidden = hideIt;
    if (hideIt) {
	if ([ECAudio ringing]) {
	    [ECAudio stopRinging];
	}
	if (alarmTestButtonTimer) {
	    [alarmTestButtonTimer invalidate];
	    alarmTestButtonTimer = nil;
	}
    }
    [EOClock setupLocalNotificationForAlarmStateEnabled:alarmSwitch.on];
}

- (void)silenceAction:(id)sender {
    [ECAudio stopRinging];
    [self revertAlarmTestButton];
}

- (void)UNTPSwitchAction:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"EOUseNTP"];
    if (sender.on) {
        ESTime::enableSync();
    } else {
        ESTime::disableSync();
    }
}

- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController {
    printf("Setting alarm time from popover\n");
    alarmValueLabel.text = [alarmTimeFormatter stringFromDate:[EOClock alarmTime]->currentDate()];
}

- (IBAction)totSwitchAction:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:@"EONoonOnTop"];
    [[EOClock theClock] reCreateMainDial];
}

- (IBAction)DALSwitchAction:(UISwitch *)sender {
    [EOBatteryAndDAL setDALOption:sender.on whenPluggedIn:sender==DALaSwitch];
}

- (IBAction)ULSSwitchAction:(id)sender {
    [self setFieldsAndLabels];
    latField.hidden  = ULSSwitch.on;
    longField.hidden = ULSSwitch.on;
    latlongHelpLabel.hidden = ULSSwitch.on;
    latLabel.hidden  = !ULSSwitch.on;
    longLabel.hidden = !ULSSwitch.on;
    if (sender) {
	[[NSUserDefaults standardUserDefaults] setBool:ULSSwitch.on forKey:@"EOUseLocationServices"];
        ESLocation *location = [[EOClock theClock] env]->location();
	if (ULSSwitch.on) {
            location->setToDevice();
	    [self setLabels];
	} else {
            location->setToUserLocationAtLastLocation();
	}
    }
}

- (IBAction)done {
    if (alarmTestButtonTimer) {
	[alarmTestButtonTimer invalidate];
	alarmTestButtonTimer = nil;
	if ([ECAudio ringing]) {
	    [ECAudio stopRinging];
	}
    }
    [self.delegate flipsideViewControllerDidFinish:self];	
}
// UITextFieldDelegate methods (for lat/long entry)			---------------------------------------------------------

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    //traceEnter("textFieldDidBeginEditing");
    //traceExit("textFieldDidBeginEditing");
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    //traceEnter("textFieldDidEndEditing");
    if (!ULSSwitch.on) {
	double lat = [latField.text floatValue];
	lat = fmin(90, fmax(-90, lat));
	double lng = [longField.text floatValue];
	lng = fmin(180, fmax(-180, lng));
        [[EOClock theClock] env]->location()->setToUserLocation(lat, lng, 0/*accuracyInMeters*/);
    }
    [textField resignFirstResponder];
    //traceExit("textFieldDidEndEditing");
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    //traceEnter("textFieldShouldReturn");
    [textField resignFirstResponder];
    //traceExit ("textFieldShouldReturn");
    return YES;
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}


// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask) supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)dealloc {
    [super dealloc];
}


@end
