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

- (id)init
{
	if (self = [super init]) {
		toolPath	= nil;
		appPath		= nil;
	}
	return self;
}

- (NSString*)getLineFromCommand:(NSString*)command
{
	char line[1000];
	FILE * output = popen([command UTF8String], "r");
	if (fgets(line, 1000, output)) {
		size_t len = strlen(line);
		if (len && line[len-1]=='\n') {
			line[len-1] = 0;
			return [NSString stringWithUTF8String:line];
		}
	} else
		NSLog(@"Failed command: %@ %s (%d)\n", command, feof(output) ? "EOF" : "Error", errno);
	pclose(output);
	return nil;
}

- (NSString *)lilypondVersion:(NSString *)path
{
	NSString * cmd 	= 
		[NSString stringWithFormat:
						  @"%@ --version | head -1 | awk '{ print $3 }'",
					  path];
	return [self getLineFromCommand:cmd];
}

- (void)awakeFromNib
{
	[lilypondPath setAutoenablesItems:NO];

	NSUserDefaults*	defaults	= [NSUserDefaults standardUserDefaults];
	NSFileManager * fileManager	= [NSFileManager defaultManager];
	NSString * 		lilyPath 	= [defaults stringForKey:@"VLLilypondPath"];
	NSRange 		app 		= [lilyPath rangeOfString:@".app"];
	bool			wantTool	= app.location == NSNotFound;
	
	if ([fileManager isExecutableFileAtPath:lilyPath]) {
		//
		// Path still valid, figure out what it is
		//
		if (wantTool)
			toolPath	= lilyPath;
		else
			appPath		= lilyPath;
	}
	if (!appPath) 
		appPath = 	
			[[[NSWorkspace sharedWorkspace]
				absolutePathForAppBundleWithIdentifier:@"org.lilypond.lilypond"]
				stringByAppendingPathComponent:@"Contents/Resources/bin/lilypond"];
	if (!toolPath) 
		toolPath = [self getLineFromCommand:@"bash -l which lilypond"];

	NSString * appVersion  = nil;
	NSString * toolVersion = nil;

	if (appPath) {
		appVersion		= [self lilypondVersion:appPath];
		if (!appVersion)
			appPath	= nil;
		else
			[appPath retain];
	}
	if (toolPath) {
		toolVersion		= [self lilypondVersion:toolPath];
		if (!toolVersion)
			toolPath	= nil;		
		else
			[toolPath retain];
	}	
		
	NSMenuItem	*	toolItem	= [lilypondPath itemAtIndex:0];
	NSMenuItem	*	appItem		= [lilypondPath itemAtIndex:1];
	
	if (toolPath) {
		[toolItem setTitle:
					  [NSString stringWithFormat:@"%@ (%@)", toolPath, toolVersion]];
	} else {
		[toolItem setTitle:@"lilypond tool not installed"];
		[toolItem setEnabled:NO];
	}
	if (appPath) {
		NSRange r = [appPath rangeOfString:@"/Contents/Resources"];
		[appItem setTitle:
					 [NSString stringWithFormat:@"%@ (%@)", 
							   [appPath substringToIndex:r.location], appVersion]];
	} else {
		[appItem setTitle:@"Lilypond.app not installed"];
		[appItem setEnabled:NO];
	}
	if (!toolPath && appPath) {
		wantTool = false;
		[defaults setObject:appPath forKey:@"VLLilypondPath"];
	} else if (toolPath && !appPath) {
		wantTool = true;
		[defaults setObject:toolPath forKey:@"VLLilypondPath"];
	}
	[lilypondPath selectItemWithTag:wantTool ? 0 : 1];
}

- (IBAction) playNewPitch:(id)sender
{
	VLNote note(VLFraction(1,4), [sender intValue]);
	
	VLSoundOut::Instance()->PlayNote(note);
}

- (IBAction) selectLilypondPath:(id)sender
{
	NSUserDefaults*	defaults	= [NSUserDefaults standardUserDefaults];

	switch ([[sender selectedItem] tag]) {
	case 0:
		[defaults setObject:toolPath forKey:@"VLLilypondPath"];
		break;
	case 1:
		[defaults setObject:appPath forKey:@"VLLilypondPath"];
		break;
	default:
		break;
	}
}

@end
