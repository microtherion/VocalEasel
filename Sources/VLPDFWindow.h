//
// File: VLPDFWindow.h - Manipulate preview window
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2005-2007 Matthias Neeracher
//

#import <Cocoa/Cocoa.h>

@interface VLPDFWindow : NSWindowController <NSToolbarDelegate> {
	IBOutlet id	pdfView;
	IBOutlet id prevPageItem;
	IBOutlet id nextPageItem;
	IBOutlet id zoomInItem;
	IBOutlet id zoomOutItem;
}

- (void)reloadPDF;

@end
