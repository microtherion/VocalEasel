//
//  VLGrooveController.h
//  Vocalese
//
//  Created by Matthias Neeracher on 2/1/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class VLSheetView;

@interface VLGrooveController : NSWindowController {
	NSDictionary * 			fGrooves;
	IBOutlet NSBrowser *	fBrowser;
	IBOutlet NSTextField *	fDescription;
	IBOutlet NSButton *		fOKButton;
	NSString *				fStyle;
	NSDictionary *			fSubStyles;
	NSArray *				fSubStyleList;
	NSPredicate *			fSubStyleFilter;
}

- (id) initWithSheetView:(VLSheetView *)view;
- (IBAction)endSheet:(id)sender;
- (IBAction)updateDescription:(id)sender;

@end

// Local Variables:
// mode:ObjC
// End:
