//
//  EOMoonAgeView.h
//  Emerald Orrery
//
//  Created by Steve Pucci on 4 Dec 2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EOHandView.h"


@interface EOMoonAgeView : EOHandView {
    double      outerRadius;
    double      innerRadius;
}

- (EOMoonAgeView *)initWithOuterRadius:(double)outerRadius
			   innerRadius:(double)innerRadius
				     x:(double)ax
				     y:(double)ay
				update:(double)aUpdate;
@end
