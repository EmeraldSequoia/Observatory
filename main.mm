//
//  main.m
//  Emerald Orrery
//
//  Created by Bill Arnett on 3/16/2010.
//  Copyright Emerald Sequoia LLC 2010. All rights reserved.
//

#import <UIKit/UIKit.h>
#include "ESTime.hpp"
#include "ESCalendar.hpp"

int main(int argc, char *argv[]) {
    
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    //ESCalendar_init();
    ESTime::startOfMain("Obs");
    int retVal = UIApplicationMain(argc, argv, nil, nil);
    [pool release];
    return retVal;
}
