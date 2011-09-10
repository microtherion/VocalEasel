//
// File: VLSheetWindow.mm - Control lead sheet editing window
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2005-2011 Matthias Neeracher
//

#import "VLSheetWindow.h"
#import "VLDocument.h"
#import "VLPDFWindow.h"
#import "VLLogWindow.h"
#import "VLSoundOut.h"
#import "VLSheetView.h"
#import "VLSheetViewSelection.h"

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

- (BOOL)canExtendSelection:(VLRegion)region
{
    return NO;
}

- (void)extendSelection:(size_t)measure at:(VLFract)at
{
}

- (BOOL)hidden
{
    return NO;
}

@end

@implementation VLSheetWindow

@synthesize logWin;

- (id)initWithWindow:(NSWindow *)window
{
	if (self = [super initWithWindow:window]) {
		editTarget			= nil;
        NSNotificationCenter * nc   = [NSNotificationCenter defaultCenter];
        NSOperationQueue *     oq   = [NSOperationQueue mainQueue];
        soundStartObserver          = [nc addObserverForName:(NSString*)kVLSoundStartedNotification 
                                                      object:nil queue:oq usingBlock:^(NSNotification *note) {
            [[[self window] toolbar] validateVisibleItems];
        }];
        soundStopObserver           = [nc addObserverForName:(NSString*)kVLSoundStoppedNotification 
                                                      object:nil queue:oq usingBlock:^(NSNotification *note) {
            [[[self window] toolbar] validateVisibleItems];
        }];
	}
	return self;
}

- (void) dealloc
{
    NSNotificationCenter * nc   = [NSNotificationCenter defaultCenter];
    [nc removeObserver:soundStartObserver];
    [nc removeObserver:soundStopObserver];
}

- (VLEditable *)editTarget
{
	return editTarget;
}

- (void)setEditTarget:(VLEditable *)editable
{
    [editTarget autorelease];
	editTarget = editable;
}

- (void) startAnimation
{
	[progressIndicator startAnimation:self];
}

- (void) stopAnimation
{
	[progressIndicator stopAnimation:self];
}

- (IBAction) zoomIn: (id) sender
{
	[sheetView zoomIn:sender];
}

- (IBAction) zoomOut: (id) sender
{
	[sheetView zoomOut:sender];
}

- (void) mouseMoved:(NSEvent *)event
{
	[sheetView mouseMoved:event];
}

- (void) willPlaySequence:(MusicSequence)music
{
	[sheetView willPlaySequence:music];
}

- (IBAction) togglePlayElements:(id)sender
{
	[[self document] setPlayElements:[[self document] playElements] ^ [sender tag]];
}

- (BOOL) validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)item
{
	if ([item action] == @selector(togglePlayElements:)) {
        NSMenuItem * menuItem = (NSMenuItem *)item;
		if (int tag = [item tag])
			[menuItem setState:([[self document] playElements] & tag) != 0];
    } else if ([item action] == @selector(playStop:)) {
        NSMenuItem *    menuItem = [(NSObject *)item isKindOfClass:[NSMenuItem class]] ? (NSMenuItem *)item : nil;
        NSToolbarItem * toolItem = menuItem ? nil : (NSToolbarItem *)item;
        if (VLSoundOut::Instance()->Playing()) {
            [menuItem setTitle:@"Stop"];
            [toolItem setLabel:@"Stop"];
            [toolItem setImage:[NSImage imageNamed:@"stop.icns"]];
        } else {
            [menuItem setTitle:@"Play"];
            [toolItem setLabel:@"Play"];
            [toolItem setImage:[NSImage imageNamed:@"play.icns"]];
        }
    }
    
	return YES;
}

- (IBAction) showLog:(id)sender
{
	[logWin showWindow:sender];
}

- (void) showLogAndBeep
{
    [logWin showWindow:self];
    NSBeep();
}

- (IBAction) showOutput:(id)sender
{
	[[self document] createTmpFileWithExtension:@"pdf" ofType:VLPDFType];
    [pdfWin showWindow:self];
	[pdfWin reloadPDF];
}

- (IBAction) stop:(id)sender
{
    VLSoundOut::Instance()->Stop();
}

- (IBAction) playStop:(id)sender
{	
	if (VLSoundOut::Instance()->Playing()) 
        [self stop:sender];
    else
        [[self document] playSong];
}

- (IBAction) playMusic:(id)sender
{
	switch ([sender tag]) {
    case 1: 	// Fwd
        VLSoundOut::Instance()->Fwd();
        break;
    case -1:	// Rew
        VLSoundOut::Instance()->Bck();
        break;
	}
}

- (IBAction) adjustTempo:(id)sender
{
	[[self document] setSongTempo:[[self document] songTempo]+[sender tag]];
}

- (IBAction)editDisplayOptions:(id)sender
{
	NSUndoManager * undoMgr = [[self document] undoManager];	
	[undoMgr setGroupsByEvent:NO];
	[undoMgr beginUndoGrouping];
        
	[NSApp beginSheet:displaySheet modalForWindow:[self window]
        modalDelegate:self 
       didEndSelector:@selector(didEndDisplaySheet:returnCode:contextInfo:)
          contextInfo:nil];
}

- (void)didEndDisplaySheet:(NSWindow *)sheet returnCode:(int)returnCode 
               contextInfo:(void *)ctx
{
	NSUndoManager * undoMgr = [[self document] undoManager];
	[undoMgr setActionName:@"Display Options"];
	[undoMgr endUndoGrouping];
	[undoMgr setGroupsByEvent:YES];
    
	switch (returnCode) {
        case NSAlertFirstButtonReturn:
            [sheetView needsRecalculation];
            break;
        default:
            [undoMgr undo];
            break;
	}	
	[sheet orderOut:self];
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window
{
    return [[self document] undoManager];
}

@end
