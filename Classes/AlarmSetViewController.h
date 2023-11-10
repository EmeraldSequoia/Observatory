//
//  AlarmSetViewController.h
//  Emerald Observatory
//
//  Created by Bill Arnett on 5/30/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface AlarmSetViewController : UIViewController {
    IBOutlet UILabel	    *pickerLabel;
    IBOutlet UIDatePicker   *picker;
}

- (IBAction) pickerValueChanged:(id)sender;

@end
