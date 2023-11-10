//
//  EOHandTriangleView.h
//  Emerald Orrery
//
//  Created by Bill Arnett on 3/17/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EOHandView.h"

@interface EOHandTriangleView : EOHandView {
    double centerRadius;
    double ballRadius;
}

- (EOHandTriangleView *)initWithKind:(EOHandKind)aKind length:(double)aLength width:(double)aWidth x:(double)ax y:(double)ay update:(double)aUpdate strokeColor:(UIColor *)asColor fillColor:(UIColor *)afColor;

@end
