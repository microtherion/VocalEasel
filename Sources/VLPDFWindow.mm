//
//  VLPDFWindow.m
//  Lilypond
//
//  Created by Matthias Neeracher on 5/29/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "VLPDFWindow.h"
#import "VLPDFView.h"

@implementation VLPDFWindow

static NSString* 	sOutputToolbarIdentifier		= @"Lilypond Output Toolbar Identifier";
static NSString*	sPrevPageToolbarItemIdentifier	= @"Prev Page Toolbar Item Identifier";
static NSString*	sNextPageToolbarItemIdentifier	= @"Next Page Toolbar Item Identifier";
static NSString*	sZoomInToolbarItemIdentifier	= @"Zoom In Toolbar Item Identifier";
static NSString*	sZoomOutToolbarItemIdentifier	= @"Zoom Out Toolbar Item Identifier";

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName
{
	return [displayName stringByAppendingString: @" - Output"];
}

- (void)synchronizeWindowTitleWithDocumentName
{
	[super synchronizeWindowTitleWithDocumentName];
	[self reloadPDF];
}

- (void)reloadPDF
{
	if (pdfView) {
		NSString *		inString	= [[[self document] fileURL] path];
		NSString *		baseString  = [inString stringByDeletingPathExtension];
		NSString *		outString	= [baseString stringByAppendingPathExtension: @"pdf"]; 
		NSURL *			pdfURL		= [NSURL fileURLWithPath: outString];
		PDFDocument *	pdfDoc		= [[[PDFDocument alloc] initWithURL: pdfURL] autorelease];
		[(PDFView *)pdfView setDocument: pdfDoc]; 
	}
}

- (IBAction)printDocument:(id)sender
{
	[pdfView printWithInfo: [NSPrintInfo sharedPrintInfo] autoRotate: YES];
}

- (void)windowDidLoad
{
	// Create a new toolbar instance, and attach it to our document window 
    NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier: sOutputToolbarIdentifier] autorelease];
    
    // Set up toolbar properties: Allow customization, give a default display mode, and remember state in user defaults 
    [toolbar setAllowsUserCustomization: YES];
    [toolbar setAutosavesConfiguration: YES];
    
    // We are the delegate
    [toolbar setDelegate: self];
    
    // Attach the toolbar to the document window 
    [[self window] setToolbar: toolbar];
}


- (NSToolbarItem *) toolbar: (NSToolbar *)toolbar itemForItemIdentifier: (NSString *) itemIdent willBeInsertedIntoToolbar:(BOOL) willBeInserted {
    // Required delegate method:  Given an item identifier, this method returns an item 
    // The toolbar will use this method to obtain toolbar items that can be displayed in the customization sheet, or in the toolbar itself 
    NSToolbarItem *	toolbarItem = nil;
    id				prototype   = nil;
	
    if ([itemIdent isEqual: sPrevPageToolbarItemIdentifier]) 
		prototype = prevPageItem;
    else if ([itemIdent isEqual: sNextPageToolbarItemIdentifier]) 
		prototype = nextPageItem;
    else if ([itemIdent isEqual: sZoomInToolbarItemIdentifier]) 
		prototype = zoomInItem;
    else if ([itemIdent isEqual: sZoomOutToolbarItemIdentifier]) 
		prototype = zoomOutItem;
	
	if (prototype) {
        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
	
        // Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel: [prototype title]];
		[toolbarItem setPaletteLabel: [prototype alternateTitle]];
	
		// Set up a reasonable tooltip, and image   Note, these aren't localized, but you will likely want to localize many of the item's properties 
		[toolbarItem setToolTip: [prototype toolTip]];
		[toolbarItem setImage: [prototype image]];
	
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: [prototype target]];
		[toolbarItem setAction: [prototype action]];
    } else {
		// itemIdent refered to a toolbar item that is not provide or supported by us or cocoa 
		// Returning nil will inform the toolbar this kind of item is not supported 
		toolbarItem = nil;
    }
    return toolbarItem;
}

- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *) toolbar {
    // Required delegate method:  Returns the ordered list of items to be shown in the toolbar by default    
    // If during the toolbar's initialization, no overriding values are found in the user defaults, or if the
    // user chooses to revert to the default items this set will be used 
    return [NSArray arrayWithObjects: NSToolbarPrintItemIdentifier, NSToolbarSeparatorItemIdentifier,
		sPrevPageToolbarItemIdentifier, sNextPageToolbarItemIdentifier, NSToolbarSeparatorItemIdentifier, 
		sZoomInToolbarItemIdentifier, sZoomOutToolbarItemIdentifier, nil];
}

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar {
    // Required delegate method:  Returns the list of all allowed items by identifier.  By default, the toolbar 
    // does not assume any items are allowed, even the separator.  So, every allowed item must be explicitly listed   
    // The set of allowed items is used to construct the customization palette 
    return [NSArray arrayWithObjects: 	sPrevPageToolbarItemIdentifier, sNextPageToolbarItemIdentifier, 
			sZoomInToolbarItemIdentifier, sZoomOutToolbarItemIdentifier,
			NSToolbarPrintItemIdentifier, NSToolbarCustomizeToolbarItemIdentifier, 
			NSToolbarFlexibleSpaceItemIdentifier, NSToolbarSpaceItemIdentifier, NSToolbarSeparatorItemIdentifier, nil];
}

- (void) toolbarWillAddItem: (NSNotification *) notif {
    // Optional delegate method:  Before an new item is added to the toolbar, this notification is posted.
    // This is the best place to notice a new item is going into the toolbar.  For instance, if you need to 
    // cache a reference to the toolbar item or need to set up some initial state, this is the best place 
    // to do it.  The notification object is the toolbar to which the item is being added.  The item being 
    // added is found by referencing the @"item" key in the userInfo 
}  

- (void) toolbarDidRemoveItem: (NSNotification *) notif {
    // Optional delegate method:  After an item is removed from a toolbar, this notification is sent.   This allows 
    // the chance to tear down information related to the item that may have been cached.   The notification object
    // is the toolbar from which the item is being removed.  The item being added is found by referencing the @"item"
    // key in the userInfo 
}

- (BOOL) validateToolbarItem: (NSToolbarItem *) toolbarItem {
    // Optional method:  This message is sent to us since we are the target of some toolbar item actions 
    // (for example:  of the save items action) 
	return YES;
}

@end
