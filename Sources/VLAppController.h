//
//  VLAppController.h
//  Vocalese
//
//  Created by Matthias Neeracher on 10/23/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface VLAppController : NSObject {
	IBOutlet id		lilypondPath;

	NSString *		toolPath;
	NSString *		appPath;
}

- (IBAction) playNewPitch:(id)sender;
- (IBAction) selectLilypondPath:(id)sender;
							 
@end

// Local Variables:
// mode:ObjC
// End:
