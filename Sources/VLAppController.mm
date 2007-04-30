//
// File: VLAppController.mm - Application wide controller
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2005-2007 Matthias Neeracher
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
	char 		line[1000];
	FILE * 		output 	= popen([command UTF8String], "r");
	NSString *	outLine	= nil;
	for (int attempts=0; attempts<5; ++attempts) 
		if (fgets(line, 1000, output)) {
			size_t len = strlen(line);
			if (len && line[len-1]=='\n') {
				line[len-1] = 0;
				outLine = [NSString stringWithUTF8String:line];
			}
		} else if (feof(output))
			break;
		else	
			clearerr(output);

	if (!outLine)
		NSLog(@"Failed command: %@ %s (%d)\n", command, 
			  feof(output) ? "EOF" : "Error", errno);

	pclose(output);

	return outLine;
}

- (NSString *)lilypondVersion:(NSString *)path
{
	NSString * cmd 	= 
		[NSString stringWithFormat:
						  @"%@ --version | head -1 | awk '{ print $3 }'",
					  path];
	return [self getLineFromCommand:cmd];
}

- (void)adviseLilypondInstallation:(id)sender
{
//	[NSApp terminate:self];
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

- (BOOL)promptForSoftwareInstallation:(NSString *)label
							withTitle:(NSString *)title
						  explanation:(NSString *)expl
							   script:(NSString *)script
								  url:(NSURL *)url
{
	NSString * hasFink = [self getLineFromCommand:@"bash -l which fink"];

	int response = 
		[[NSAlert alertWithMessageText:title
				  defaultButton: hasFink 
				  ? @"Install through fink" 
				  : label
				  alternateButton:@"Continue"
				  otherButton:hasFink 
				  ? label
				  : @""
				  informativeTextWithFormat: expl, hasFink 
				  ? @"\n\nSince you have fink installed already, you may "
				  "choose to install this package through fink." : @""]
			runModal];

	if (response == NSAlertAlternateReturn)
		return NO;
	else if (hasFink && response == NSAlertDefaultReturn) {
		NSDictionary * error;
		NSURL *		   scptURL = 
			[NSURL fileURLWithPath:
			   [[NSBundle mainBundle] pathForResource:script
									  ofType:@"scpt"]];
		NSAppleScript * scpt = 
			[[NSAppleScript alloc] 
				initWithContentsOfURL:scptURL error:&error];
		[scpt executeAndReturnError:&error];
	} else {
		[[NSWorkspace sharedWorkspace] openURL:url];
	}
	return YES;
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
	BOOL       quit	   = NO;

	if (!toolPath && !appPath) 
		if ([self promptForSoftwareInstallation:@"Download from lilypond.org"
				  withTitle: @"Lilypond Not Found!"
				  explanation: 
					  @"Couldn't find an installation of Lilypond, which "
				  "is needed to typeset the sheet music. If you continue "
				  "without installing, you will be unable to preview, "
				  "print, or save as PDF.%@"
				  script:@"installLilypond"
				  url:[NSURL URLWithString:@"http://lilypond.org/web/install"]]
		)
			quit = YES;
	if (![self getLineFromCommand:@"bash -l which python2.5"]) 
		if ([self promptForSoftwareInstallation:@"Download from python.org"
				  withTitle: @"Python 2.5 Not Found!"
				  explanation: 
					  @"Python 2.5 is needed to play accompaniments. The "
				  "version preinstalled on your computer is not recent "
				  "enough. If you continue without installing, you will be "
				  "unable to play accompaniments, or save as MIDI.%@"
				  script:@"installPython"
				  url:[NSURL URLWithString:@"http://www.python.org/download"]]
		)
			quit = YES;

	if (quit) {
		[[NSAlert alertWithMessageText:@"Quit and Restart"
					  defaultButton: @"OK" alternateButton: @"" otherButton: @""
					  informativeTextWithFormat:
					  @"The software you have chosen to install will be "
				  "available after you restart this application."]
			runModal];
		[NSApp terminate:self];
	}
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

- (IBAction) goToHelpURL:(id)sender
{
	NSString * helpString;

	switch ([sender tag]) {
	case 0:
		helpString	= @"http://vocaleasel.sf.net";
		break;
	case 1:
		helpString	= @"http://sourceforge.net/tracker/?func=add&group_id=195076&atid=951989";
		break;
	case 2:
		helpString = @"http://sourceforge.net/tracker/?func=add&group_id=195076&atid=951992";
		break;
	}
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:helpString]];
}
						   
@end
