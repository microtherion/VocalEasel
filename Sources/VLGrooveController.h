//
//  VLGrooveController.h
//  Vocalese
//
//  Created by Matthias Neeracher on 2/1/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class VLSheetView;
@class VLDocument;

@interface VLGrooveController : NSWindowController {
	NSDictionary * 			fGrooves;
	IBOutlet NSBrowser *	fBrowser;
	IBOutlet NSTextField *	fDescription;
	IBOutlet NSButton *		fOKButton;
	IBOutlet NSButton *		fPlayButton;
	NSString *				fStyle;
	NSDictionary *			fSubStyles;
	NSArray *				fSubStyleList;
	NSPredicate *			fSubStyleFilter;
	VLDocument *			fDocument;
}

- (id) initWithSheetView:(VLSheetView *)view;
- (IBAction)endSheet:(id)sender;
- (IBAction)updateDescription:(id)sender;
- (IBAction) togglePlay:(id)sender;

@end

// Local Variables:
// mode:ObjC
// End:
