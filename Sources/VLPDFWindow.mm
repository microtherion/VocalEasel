//
// File: VLPDFWindow.mm - Manipulate preview window
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2005-2011 Matthias Neeracher
//

#import "VLPDFWindow.h"
#import "VLPDFView.h"
#import "VLDocument.h"

@implementation VLPDFWindow

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName
{
	return [displayName stringByAppendingString: @" - Output"];
}

- (void)synchronizeWindowTitleWithDocumentName
{
	[super synchronizeWindowTitleWithDocumentName];
	[self reloadPDF];
}

- (IBAction)showWindow:(id)sender
{
	[super showWindow:sender];
}

- (void)reloadPDF
{
	if (pdfView) {
		VLDocument *doc	   = [self document];
		NSURL * 	pdfURL = [doc fileURLWithExtension:@"pdf"];
		if (!pdfURL) {
            NSURL *         workURL     = [doc workURL];
			NSFileWrapper * wrapper		= 
				[[[NSFileWrapper alloc] initWithURL:workURL options:0 error:nil] autorelease];
			//
			// Find newest pdf file
			//
			NSEnumerator * 	w			= [[wrapper fileWrappers] objectEnumerator];
			NSString	 *  pdfPath		= nil;
			NSDate 		 * 	pdfDate		= nil;
			while (wrapper = [w nextObject]) {
				NSString * path = [wrapper filename];
				if (![[path pathExtension] isEqual:@"pdf"])
					continue;
				NSDate *   date = [[wrapper fileAttributes] 
									  objectForKey:NSFileModificationDate];
				if (!pdfPath || [date compare:pdfDate]==NSOrderedAscending) {
					pdfPath	= path;
					pdfDate	= date;
				}
			}
			if (pdfPath) 
				pdfURL	= [workURL URLByAppendingPathComponent:pdfPath];
		}
		if (pdfURL) {
			PDFDocument *	pdfDoc 	= 
				[[[PDFDocument alloc] initWithURL:pdfURL] autorelease];
			[(PDFView *)pdfView setDocument: pdfDoc]; 
			[pdfView setNeedsDisplay:YES];
		}
	}
}

- (IBAction)printDocument:(id)sender
{
	[pdfView printWithInfo: [NSPrintInfo sharedPrintInfo] autoRotate: YES];
}

- (void)windowDidLoad
{
}

@end
