    //
//  AlarmSetViewController.m
//  Emeradl Observatory
//
//  Created by Bill Arnett on 5/30/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import "AlarmSetViewController.h"
#import	"EOClock.h"
#import "ESTime.hpp"
#import "ESWatchTime.hpp"
#import "ESCalendar.hpp"

@implementation AlarmSetViewController

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
    // In the clock's time zone (a location picked on the map brings its own), which the alarm is set in
    // (setAlarmTime:), not the device's
    picker.timeZone = ESCalendar_nsTimeZone(ESCalendar_localTimeZone());
    if ([EOClock alarmTime] == nil) {
	picker.date = [NSDate dateWithTimeIntervalSinceReferenceDate:ESTime::currentTime()];
    } else {
	picker.date = [EOClock alarmTime]->currentDate();
    }
    pickerLabel.text = NSLocalizedString(@"Set the alarm time:", "label for alarm time setting widget");
}


- (IBAction) pickerValueChanged:(id)sender {
    assert(sender == picker);
    [EOClock setAlarmTime:picker.date];
}

- (UIInterfaceOrientationMask) supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)dealloc {
    [super dealloc];
}


@end
