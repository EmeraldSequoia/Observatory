//
//  EOHandNeedleView.h
//  Emerald Orrery
//
//  Created by Bill Arnett on 3/25/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "EOHandView.h"
#import "EOScheduledView.h"


@interface EOHandNeedleView: EOHandView {
    double	ballRadius;
}

- (EOHandNeedleView *)initWithKind:(EOHandKind)aKind length:(double)aLength width:(double)aWidth x:(double)ax y:(double)ay update:(double)aUpdate strokeColor:(UIColor *)asColor ballRadius:(double)ballRadius;

@end
