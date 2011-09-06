//
// File: VLKeyValueUndo.h - Automatically handle undo functionality for 
//                          key-value paths
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2007-2011 Matthias Neeracher
//

#import <Cocoa/Cocoa.h>

typedef void (^VLKeyValueUpdateHook)(NSString * keyPath);

@interface VLKeyValueUndo : NSObject {
	id                      owner;
	NSDictionary *          keysAndNames;
    VLKeyValueUpdateHook    updateHook;
}

- (id)initWithOwner:(id)owner keysAndNames:(NSDictionary *)keysAndNames update:(VLKeyValueUpdateHook)hook;
- (id)initWithOwner:(id)owner keysAndNames:(NSDictionary *)keysAndNames;

@end
