//
// File: VLPDFWindow.h - Manipulate preview window
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2005-2011 Matthias Neeracher
//

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

@interface VLPDFWindow : NSWindowController <NSToolbarDelegate> {
	IBOutlet PDFView *	pdfView;
}

- (void)reloadPDF;

@end
