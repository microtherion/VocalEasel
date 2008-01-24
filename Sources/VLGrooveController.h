//
// File: VLGrooveController.h - Control groove selection sheet
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2007 Matthias Neeracher
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
	VLSheetView *			fView;
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
