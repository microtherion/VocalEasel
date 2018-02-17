//
// File: VLAppController.h - Application wide controller
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2005-2008 Matthias Neeracher
//

#import <Cocoa/Cocoa.h>

@interface VLAppController : NSObject {
	IBOutlet NSMenu *   lilypondPath;
	IBOutlet id			mirrorWin;
	IBOutlet NSMenu *   debugMenu;

	NSString *			toolPath;
	NSString *			appPath;
	NSString *			lamePath;
}

- (IBAction) playNewPitch:(id)sender;
- (IBAction) selectLilypondPath:(id)sender;
- (IBAction) goToHelpPage:(id)sender;							 
- (IBAction) goToHelpURL:(id)sender;							 
- (IBAction) showMirror:(id)sender;

- (BOOL) lameIsInstalled;

@end

// Local Variables:
// mode:ObjC
// End:
