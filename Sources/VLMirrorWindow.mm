//
//   File: VLMirrorWindow.mm - Control video "Mirror"
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright ¬© 2007 Matthias Neeracher
//

#import "VLMirrorWindow.h"

@implementation VLMirrorWindow

- (id)init
{
	return [super initWithWindowNibName:@"VLMirrorWindow"];
}

- (void)showWindow:(id)sender
{
	[super showWindow:sender];
	[mirrorComposition start:sender];
	[[self window] setContentAspectRatio:NSMakeSize(20.0, 15.0)];
}

- (void)windowWillClose:(NSNotification *)notification
{
	[mirrorComposition stop:self];
}

@end
