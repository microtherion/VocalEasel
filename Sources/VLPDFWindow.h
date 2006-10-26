//
//  VLPDFWindow.h
//  Vocalese
//
//  Created by Matthias Neeracher on 5/29/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface VLPDFWindow : NSWindowController {
	IBOutlet id	pdfView;
	IBOutlet id prevPageItem;
	IBOutlet id nextPageItem;
	IBOutlet id zoomInItem;
	IBOutlet id zoomOutItem;
}

- (void)reloadPDF;

@end
