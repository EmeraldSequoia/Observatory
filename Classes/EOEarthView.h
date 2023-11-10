//
//  EOEarthView.h
//  Emerald Orrery
//
//  Created by Bill Arnett on 3/22/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EOHandView.h"


@interface EOEarthView : EOHandView {
    UIImage	    *img;
    int		    monthLoaded;
}

- (EOEarthView *)initWithX:(double)ax y:(double)ay width:(double)w height:(double)h update:(double)aUpdate;

@end
