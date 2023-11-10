/*
 *  ECTrace.h
 *  Emerald Orrery/Chronometer
 *
 *  Created by Bill Arnett on 9/29/2009.
 *  Copyright 2009 Emerald Sequoia LLC. All rights reserved.
 *
 */

#import "Utilities.h"

#ifdef ECTRACE
extern "C" {
extern NSString *traceTabs();
extern void traceEnter(const char *msg);
extern void traceExit(const char *msg);
}
#define tracePrintf(a)      {[Utilities noteTimeAtPhaseWithString:[traceTabs() stringByAppendingString:@a]];}
#define tracePrintf1(a,b)   {[Utilities noteTimeAtPhaseWithString:[traceTabs() stringByAppendingString:[NSString stringWithFormat:@a,b]]];}
#define tracePrintf2(a,b,c) {[Utilities noteTimeAtPhaseWithString:[traceTabs() stringByAppendingString:[NSString stringWithFormat:@a,b,c]]];}
#define tracePrintf3(a,b,c,d) {[Utilities noteTimeAtPhaseWithString:[traceTabs() stringByAppendingString:[NSString stringWithFormat:@a,b,c,d]]];}
#define tracePrintf4(a,b,c,d,e) {[Utilities noteTimeAtPhaseWithString:[traceTabs() stringByAppendingString:[NSString stringWithFormat:@a,b,c,d,e]]];}
#else
#define traceTab() {;}
#define traceEnter(x) {;}
#define traceExit(x) {;}
#define tracePrintf(a) {;}
#define tracePrintf1(a,b) {;}
#define tracePrintf2(a,b,c) {;}
#define tracePrintf3(a,b,c,d) {;}
#define tracePrintf4(a,b,c,d,e) {;}
#endif
