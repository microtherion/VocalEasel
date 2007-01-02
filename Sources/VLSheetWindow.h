//
//  VLSheetWindow.h
//  Lilypond
//
//  Created by Matthias Neeracher on 5/29/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface VLEditable : NSObject 
{
}

- (NSString *) stringValue;
- (void) setStringValue:(NSString*)val;
- (BOOL) validValue:(NSString*)val;
- (void) moveToNext;
- (void) moveToPrev;
- (void) highlightCursor;

@end

@interface VLSheetWindow : NSWindowController {
	VLEditable *	editTarget;

	IBOutlet id 	runToolItem;
	IBOutlet id 	outputToolItem;
	IBOutlet id 	logToolItem;
	IBOutlet id		playToolItem;
	IBOutlet id		stopToolItem;
	IBOutlet id		zoomInToolItem;
	IBOutlet id		zoomOutToolItem;
}

- (VLEditable *) editTarget;
- (void) setEditTarget:(VLEditable *)editable;

@end
