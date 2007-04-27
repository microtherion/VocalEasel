//
// File: VLSoundSched.h - Schedule sound playing in Cocoa app
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2006-2007 Matthias Neeracher
//

#import <Cocoa/Cocoa.h>

@interface VLSoundSched : NSObject {
}

+ (void) setup;
+ (void) performSoundEvent:(id)soundEvent;

@end
