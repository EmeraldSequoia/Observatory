//
//  EObaseView.h
//  Emerald Orrery
//
//  Created by Bill Arnett on 3/15/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface EOBaseView : UIView {
    bool		    unWarped;
    UIInterfaceOrientation  orientation;
}

- (void)backgroundCheck;
- (void)setOrientation:(UIInterfaceOrientation)newOrientation;

@end
