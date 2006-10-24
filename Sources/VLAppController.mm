//
//  VLAppController.mm
//  Vocalese
//
//  Created by Matthias Neeracher on 10/23/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "VLAppController.h"
#import "VLPitchTransformer.h"
#import "VLSoundOut.h"

@implementation VLAppController

+ (void)setupDefaults
{
    // load the default values for the user defaults
    NSString * 		userDefaultsValuesPath	=
		[[NSBundle mainBundle] pathForResource:@"UserDefaults" ofType:@"plist"];
    NSDictionary * 	userDefaultsValuesDict	=
		[NSDictionary dictionaryWithContentsOfFile:userDefaultsValuesPath];
    
    // set them in the standard user defaults
    [[NSUserDefaults standardUserDefaults] registerDefaults:userDefaultsValuesDict];
    
    // if your application supports resetting a subset of the defaults to 
    // factory values, you should set those values 
    // in the shared user defaults controller
    NSArray *		resettableUserDefaultsKeys	=
		[NSArray arrayWithObjects:@"VLLowPitch",@"VLHighPitch",nil];
    NSDictionary *	initialValuesDict			=
		[userDefaultsValuesDict dictionaryWithValuesForKeys:resettableUserDefaultsKeys];
    
    // Set the initial values in the shared user defaults controller 
    [[NSUserDefaultsController sharedUserDefaultsController] setInitialValues:initialValuesDict];
}

+ (void)setupTransformers
{
	VLPitchTransformer * pitchTransformer;
    
	// create an autoreleased instance of our value transformer
	pitchTransformer = [[[VLPitchTransformer alloc] init] autorelease];
    
	// register it with the name that we refer to it with
	[NSValueTransformer setValueTransformer:pitchTransformer
		forName:@"VLPitchTransformer"];
}

+ (void)initialize
{
	[self setupDefaults];
	[self setupTransformers];
}

- (IBAction) playNewPitch:(id)sender
{
	VLNote note(VLFraction(1,4), [sender intValue]);
	
	VLSoundOut::Instance()->PlayNote(note);
}

@end
