//
// File: VLAppController.h - Application wide controller
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2005-2007 Matthias Neeracher
//

#import <Cocoa/Cocoa.h>

@interface VLAppController : NSObject {
	IBOutlet id		lilypondPath;

	NSString *		toolPath;
	NSString *		appPath;
}

- (IBAction) playNewPitch:(id)sender;
- (IBAction) selectLilypondPath:(id)sender;
- (IBAction) goToHelpURL:(id)sender;							 

@end

// Local Variables:
// mode:ObjC
// End:
