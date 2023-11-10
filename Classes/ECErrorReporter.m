//
//  ECErrorReporter.h
//  Emerald Chronometer
//
//  Created by Steve Pucci 5/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

#import "ECErrorReporter.h"
#import "OrreryAppDelegate.h"

#import <UIKit/UIKit.h>
#import "Foundation/Foundation.h"

@implementation ECErrorReporter

static ECErrorReporter *theErrorReporter = nil;

static bool errorShowing = false;

+(bool)errorShowing {
    return errorShowing;
}

+(void)setErrorShowing:(bool)val {
    assert(errorShowing != val);
    errorShowing = val;
}

-(void)reportWarning:(NSString *)errorDescription
{
    printf("Warning: %s\n", [errorDescription UTF8String]);  // Should this be under debug only?
    fflush(stdout);
    fprintf(stderr, "Warning: %s\n", [errorDescription UTF8String]);  // Should this be under debug only?
    fflush(stderr);
    if (errorShowing) {
	return;
    }
    errorShowing = true;
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Warning",@"Warning")
                                                                   message:errorDescription
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK",@"OK")
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *action) { errorShowing = false; }];
    [alert addAction:defaultAction];

    OrreryAppDelegate *appDelegate = (OrreryAppDelegate *)[[UIApplication sharedApplication] delegate];
    if (appDelegate) {
        // TODO(spucci): Present using FlipsideViewController if that's active, otherwise an error in that case.
        MainViewController *mainViewController = appDelegate.mainViewController;
        if (mainViewController) {
            [mainViewController presentViewController:alert animated:YES completion:nil];
            return;
        }
    }
    printf("********* CANNOT POST USER ERROR **********\n");
    fflush(stdout);
    fprintf(stderr, "********* CANNOT POST USER ERROR **********\n");
    fflush(stderr);
}

+(ECErrorReporter *)theErrorReporter
{
    if (!theErrorReporter) {
	theErrorReporter = [[ECErrorReporter alloc] init];
    }
    return theErrorReporter;
}


@end
