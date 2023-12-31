/*
 *  ECTrace.m
 *  Emerald Chronometer/Orrery
 *
 *  Created by Bill Arnett on 9/29/2009.
 *  Copyright 2009 Emerald Sequoia LLC. All rights reserved.
 *
 */

#include <stdio.h>
#import <UIKit/UIKit.h>
#import "Utilities.h"

static int traceIndent = 0;

NSString *traceTabs (void) {
    NSString *ret = @"";
    int i = traceIndent;
    while (i-- > 0) {
	ret = [ret stringByAppendingString:@"  "];
    }
    return ret;
}

void traceEnter(const char *msg) {
    if ([NSThread isMainThread]) {
	[Utilities noteTimeAtPhaseWithString:[traceTabs() stringByAppendingString:[NSString stringWithFormat:@"%s enter", msg]]];
    } else {
	[Utilities noteTimeAtPhaseWithString:[traceTabs() stringByAppendingString:[NSString stringWithFormat:@"%s enter on thread %lx ******************************\n", msg, (unsigned long)[NSThread currentThread]]]];
    }
    ++traceIndent;
}

void traceExit(const char *msg) {
    --traceIndent;
    [Utilities noteTimeAtPhaseWithString:[traceTabs() stringByAppendingString:[NSString stringWithFormat:@"%s exit", msg]]];
}
