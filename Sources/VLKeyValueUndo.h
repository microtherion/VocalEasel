//
// File: VLKeyValueUndo.h - Automatically handle undo functionality for 
//                          key-value paths
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2007 Matthias Neeracher
//

#import <Cocoa/Cocoa.h>

@interface VLKeyValueUndo : NSObject {
	id				owner;
	NSDictionary *	keysAndNames;
}

- (id)initWithOwner:(id)owner keysAndNames:(NSDictionary *)keysAndNames;

@end
