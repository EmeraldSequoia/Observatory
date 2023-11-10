//
//  EOBatteryAndDAL.h
//  Emerald Observatory
//
//  Created by Bill Arnett on 7/3/2010.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface EOBatteryAndDAL : NSObject {

}

+ (void)startup;
+ (void)setDALOption:(bool)val whenPluggedIn:(bool)plugged;

@end
