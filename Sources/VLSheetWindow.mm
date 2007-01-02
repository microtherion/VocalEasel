//
//  LilypondInputWin.m
//  Lilypond
//
//  Created by Matthias Neeracher on 5/29/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "VLSheetWindow.h"
#import "VLDocument.h"


@implementation VLEditable

- (NSString *) stringValue
{
	return @"";
}

- (void) setStringValue:(NSString*)val
{
}

- (BOOL) validValue:(NSString*)val
{
	return YES;
}

- (void) moveToNext
{
}

- (void) moveToPrev
{
}

- (void) highlightCursor
{
}

@end

@implementation VLSheetWindow

static NSString* 	sInputToolbarIdentifier 		= @"Vocalese Sheet Window Toolbar Identifier";
static NSString*	sOutputToolbarItemIdentifier 	= @"Output Toolbar Item Identifier";
static NSString*	sLogToolbarItemIdentifier		= @"Log Toolbar Item Identifier";
static NSString*	sRunToolbarItemIdentifier		= @"Run Toolbar Item Identifier";
static NSString*	sPlayToolbarItemIdentifier		= @"Play Toolbar Item Identifier";
static NSString*	sStopToolbarItemIdentifier		= @"Stop Toolbar Item Identifier";
static NSString*	sZoomInToolbarItemIdentifier	= @"Zoom In Toolbar Item Identifier";
static NSString*	sZoomOutToolbarItemIdentifier	= @"Zoom Out Toolbar Item Identifier";

- (id)initWithWindow:(NSWindow *)window
{
	if (self = [super initWithWindow:window]) {
		editTarget			= nil;
	}
	return self;
}

- (VLEditable *)editTarget
{
	return editTarget;
}

- (void)setEditTarget:(VLEditable *)editable
{
	editTarget = editable;
}

- (void)windowDidLoad
{
    NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier: sInputToolbarIdentifier] autorelease];

    [toolbar setAllowsUserCustomization: YES];
    [toolbar setAutosavesConfiguration: YES];    
    [toolbar setDelegate: self];
    
    [[self window] setToolbar: toolbar];
}


- (NSToolbarItem *) toolbar: (NSToolbar *)toolbar itemForItemIdentifier: (NSString *) itemIdent willBeInsertedIntoToolbar:(BOOL) willBeInserted {
    NSToolbarItem *	toolbarItem = nil;
    id				prototype   = nil;
	
    if ([itemIdent isEqual: sOutputToolbarItemIdentifier]) 
		prototype = outputToolItem;
    else if ([itemIdent isEqual: sLogToolbarItemIdentifier]) 
		prototype = logToolItem;
    else if ([itemIdent isEqual: sRunToolbarItemIdentifier]) 
		prototype = runToolItem;
    else if ([itemIdent isEqual: sPlayToolbarItemIdentifier]) 
		prototype = playToolItem;
    else if ([itemIdent isEqual: sStopToolbarItemIdentifier]) 
		prototype = stopToolItem;
    else if ([itemIdent isEqual: sZoomInToolbarItemIdentifier]) 
		prototype = zoomInToolItem;
    else if ([itemIdent isEqual: sZoomOutToolbarItemIdentifier]) 
		prototype = zoomOutToolItem;
	
	if (prototype) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
	
		[toolbarItem setLabel: [prototype title]];
		[toolbarItem setPaletteLabel: [prototype alternateTitle]];
		[toolbarItem setToolTip: [prototype toolTip]];
		[toolbarItem setImage: [prototype image]];
		[toolbarItem setTarget: [prototype target]];
		[toolbarItem setAction: [prototype action]];
    } else {
		toolbarItem = nil;
    }
    return toolbarItem;
}

- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *) toolbar {
    return [NSArray arrayWithObjects:	
						sRunToolbarItemIdentifier, 
					NSToolbarSeparatorItemIdentifier,
					sPlayToolbarItemIdentifier,
					sStopToolbarItemIdentifier,
					NSToolbarSeparatorItemIdentifier,
					sZoomInToolbarItemIdentifier, 
					sZoomOutToolbarItemIdentifier, 
					NSToolbarFlexibleSpaceItemIdentifier, 
					sOutputToolbarItemIdentifier, 
					sLogToolbarItemIdentifier, nil];
}

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar {
    return [NSArray arrayWithObjects: 	
						sRunToolbarItemIdentifier, 
					sPlayToolbarItemIdentifier,
					sStopToolbarItemIdentifier,
					sZoomInToolbarItemIdentifier, 
					sZoomOutToolbarItemIdentifier, 
					sOutputToolbarItemIdentifier, 
					sLogToolbarItemIdentifier, 
					NSToolbarCustomizeToolbarItemIdentifier, 
					NSToolbarFlexibleSpaceItemIdentifier, 
					NSToolbarSpaceItemIdentifier, 
					NSToolbarSeparatorItemIdentifier, nil];
}

@end
