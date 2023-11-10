//
//  EOMoonView.h
//  Emerald Orrery
//
//  Created by Bill Arnett on 3/18/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EOHandView.h"


@interface EOMoonView : EOHandView {
    UIImage	*img;
    double	radiusAtPerigee;
}

- (EOMoonView *)initWithName:(NSString *)fn x:(double)ax y:(double)ay radiusAtPerigee:(double)aRadius update:(double)aUpdate;

@end
