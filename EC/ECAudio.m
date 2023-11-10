//
//  ECAudio.m
//  Emerald Chronometer
//
//  Created by Bill Arnett on 1/24/2009.
//  Copyright 2009 Emerald Sequoia LLC. All rights reserved.
//

#import "ECAudio.h"
#import <AudioToolbox/AudioToolbox.h>
#import <CoreFoundation/CoreFoundation.h>
#import <AVFoundation/AVAudioSession.h>

//#undef SESSION_ALWAYS_ACTIVE
#define SESSION_ALWAYS_ACTIVE

// items needed to play a sound.
static CFURLRef		soundFileURLRef = (CFURLRef)NULL;
static SystemSoundID	soundFileID = (SystemSoundID)0;
static double		ringCounter = 0;
static double		numRings = 5;
static BOOL		lastTime = false;
static bool             ringing = false;

// items needed to play silence
static CFURLRef		silenceFileURLRef = (CFURLRef)NULL;
static SystemSoundID	silenceFileID = (SystemSoundID)0;
static NSTimer          *silenceTimer;

// Define a callback to be called when the sound is finished
// playing. So we can free memory after playing or play the sound again.
// static void MyCompletionCallback (SystemSoundID asoundFileID, void *asoundFileURLRef) {
//     assert(soundFileURLRef);
//     assert(soundFileID);
//     assert(ringCounter);

//     if (lastTime || ringCounter >= 12) {
// 	[ECAudio cleanUp:nil];
//     } else {
// 	// play it again
// 	[ECAudio ringAling];
//     }
// }

static NSTimer		   *ringTimer;

@implementation ECAudio

+ (void)startRinging:(double)rings {
    if (ringing) {
	// already ringing
	assert(soundFileURLRef);
	assert(soundFileID);
	ringCounter = 1;	// so we get another n rings
	numRings = fmax(numRings, rings);
    } else {
	ringing = true;
	numRings = rings;
	if (ringCounter == 0) {
	    
	    assert(soundFileURLRef == (CFURLRef)NULL);
	    assert(soundFileID == (SystemSoundID)0);
	    
	    // Get the main bundle for the app
	    CFBundleRef mainBundle;
	    mainBundle = CFBundleGetMainBundle();
	
	    // Get the URL to the sound file to play
	    soundFileURLRef = CFBundleCopyResourceURL(mainBundle, CFSTR ("Chime"), CFSTR ("wav"), NULL);
	
	    // Create a system sound object representing the sound file
	    OSStatus error = AudioServicesCreateSystemSoundID(soundFileURLRef, &soundFileID);
	    if (error != 0) {
#ifndef NDEBUG
		printf("AudioServicesCreate error: %d\n", (int)error);
		return;
#endif
	    }
	} else {
	    lastTime = false;  // This is the case we're restarting during the tail-off period, but we want to reset that now
	    ringCounter = 1;
	}

	// hear them ring
	[ECAudio repeatRing:nil];
    }    
}

+ (void)startSilentRinging {	// just update the ring count, no actual sound
    if (ringing) {
	ringCounter = 1;	// so we get another 11 rings
    } else {
	ringing = true;
	
	// hear them ring
	[ECAudio repeatSilentRing:nil];
    }    
}

static int activeCleanupID = 0;

+ (void)repeatRing:(void*) ignoreMe {
    if (lastTime || ringCounter >= numRings) {
	// let it fade out then cleanup
	ringTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(cleanUp:) userInfo:[NSNumber numberWithInt:++activeCleanupID] repeats:false];
	ringing = false;
	    } else {
	// play it
	[ECAudio ringAling];
	// wait a while and do it again
	ringTimer = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(repeatRing:) userInfo:nil repeats:false];
    }
}

+ (void)repeatSilentRing:(void*) ignoreMe {
    if (lastTime || ringCounter >= 20) {
	// do minimal cleanup
	ringing = false;
	lastTime = false;
	ringCounter = 0;
	ringTimer = nil;
    } else {
	// play it
	++ringCounter;
	// wait a while and do it again
	ringTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(repeatSilentRing:) userInfo:nil repeats:false];
    }
}

+ (void)ringAling {
    // dont Register the sound completion callback.
    // AudioServicesAddSystemSoundCompletion(soundFileID, NULL, NULL, MyCompletionCallback, (void *)soundFileURLRef);
    
    // activate the audio session immmediately before playback starts
#ifndef SESSION_ALWAYS_ACTIVE
    OSStatus status = AudioSessionSetActive(true);
    if (status != 0) {
#ifndef NDEBUG
	printf("AudioSessionAddPropertyListener bad status %d\n", (int)status);
#endif
    }
#endif

    // Play the sound file.
    AudioServicesPlayAlertSound(soundFileID);
    ringCounter++;
}

+ (bool)stopRinging {
    if (ringing) {
	ringing = false;
	lastTime = true;
	return true;
    } else {
	return false;
    }
}

+ (void)cleanUp:(NSTimer *) theTimer {
    lastTime = false;
    if (ringing) {
	// printf("Cleanup, somebody is asking for another ring\n");
	return;
    }
    if (activeCleanupID != [[theTimer userInfo] intValue])  {
	// printf("Obsolete cleanUp timer fire ignored\n");
	return;
    }
    // printf(" Clean UP!! \n");
    AudioServicesDisposeSystemSoundID (soundFileID);
    CFRelease (soundFileURLRef);
    soundFileID = (SystemSoundID)0;
    soundFileURLRef = (CFURLRef)NULL;
#ifndef SESSION_ALWAYS_ACTIVE
    // deactivate the audio session when the sound is finished
    AudioSessionSetActive(false);
#endif
    
    // make sure the indicator state gets updated
    ringCounter = 0;
    [ringTimer invalidate];
    ringTimer = nil;
}

+ (double)ringCount {
    return ringCounter;
}

+ (bool)ringing {
    return ringing;
}

+ (void)audioInterruptionCallback {
#ifndef NDEBUG
    printf("audioInterruptionCallback\n");
#endif
}

+(void)audioRouteChangeCallback {
    //printf("audioRouteChangeCallback\n");
}

+ (void)playSilence:(NSTimer *)aTimer {
    if (!ringCounter) {  // If we're already playing a sound, there's no need to play silence
	AudioServicesPlaySystemSound(silenceFileID);
    }
}

+ (void)setupSilentSounds {
    if (silenceTimer) {
	return;
    }

    // Get the main bundle for the app
    CFBundleRef mainBundle;
    mainBundle = CFBundleGetMainBundle();
	
    // Get the URL to the silence file to play
    silenceFileURLRef = CFBundleCopyResourceURL(mainBundle, CFSTR ("Silence"), CFSTR ("wav"), NULL);
	
    // Create a system sound object representing the silence file
    OSStatus error = AudioServicesCreateSystemSoundID(silenceFileURLRef, &silenceFileID);
    if (error != 0) {
#ifndef NDEBUG
	printf("AudioServicesCreate error: %d\n", (int)error);
	return;
#endif
    }

    // Set up the timer to go off every 10 seconds
    silenceTimer = [NSTimer scheduledTimerWithTimeInterval:10.0 target:self selector:@selector(playSilence:) userInfo:nil repeats:YES];
}

+ (void)cancelSilentSounds {
    [silenceTimer invalidate];
    silenceTimer = nil;
}

+ (void)setup {
    // New for iOS 7 support:  Use singleton AVAudioSession
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    
    NSError *error;
    BOOL st = [audioSession setCategory:AVAudioSessionCategoryAmbient error:&error];
    if (st != YES) {
#ifndef NDEBUG
        NSLog(@"audioSession setCategory failed with error: %@", [error localizedDescription]);
#endif
    }
   
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
   
    // registering the callback Audio Session Services will invoke when there's an interruption
    [notificationCenter addObserver:self selector:@selector(audioInterruptionCallback) name:AVAudioSessionMediaServicesWereResetNotification object:nil];

    // register a property listener so we're notified when there's a route change
    [notificationCenter addObserver:self selector:@selector(audioRouteChangeCallback) name:AVAudioSessionRouteChangeNotification object:nil];
    
    
#ifdef SESSION_ALWAYS_ACTIVE
    // deactivate the audio session when the sound is finished
    st = [audioSession setActive:YES error:&error];
    if (st != YES) {
#ifndef NDEBUG
        NSLog(@"audioSession setActive failed with error: %@", [error localizedDescription]);
#endif
    }
#endif

    [self setupSilentSounds];
}

@end
