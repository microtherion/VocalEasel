//
// File: VLSoundSched.mm - Schedule sound playing in Cocoa app
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2006-2007 Matthias Neeracher
//

#import "VLSoundSched.h"
#import "VLSoundOut.h"

class VLSS: public VLSoundScheduler {
	virtual void Schedule(VLSoundEvent * what, float when);
};

void VLSS::Schedule(VLSoundEvent * what, float when)
{
	[[VLSoundSched class] performSelector:@selector(performSoundEvent:) 
						  withObject:[NSNumber numberWithUnsignedLong:(unsigned long)what]	
						  afterDelay:when];
}

@implementation VLSoundSched

+ (void) setup
{
	VLSoundOut::SetScheduler(new VLSS);
}

+ (void) performSoundEvent:(id)soundEvent
{
	((VLSoundEvent *)[soundEvent unsignedLongValue])->Perform();
}

@end
