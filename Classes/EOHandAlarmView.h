//
//  EOHandAlarmView.h
//  Emerald Orrery
//
//  Created by Bill Arnett on 3/25/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EOHandView.h"

@interface EOHandAlarmView : EOHandView {
    double tailRadius;
}

- (EOHandAlarmView *)initWithKind:(EOHandKind)aKind length:(double)aLength length2:(double)len2 width:(double)aWidth x:(double)ax y:(double)ay update:(double)aUpdate strokeColor:(UIColor *)asColor fillColor:(UIColor *)afColor armStrokeColor:(UIColor *)armsColor arrowLength:(double)arrowLength tailRadius:(double)tailRadius;

@end
