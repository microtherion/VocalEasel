//
//   File: VLMirrorWindow.h - Control video "Mirror"
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright ¬© 2007 Matthias Neeracher
//

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>


@interface VLMirrorWindow : NSWindowController {
	IBOutlet QCView *	mirrorComposition;
}

@end
