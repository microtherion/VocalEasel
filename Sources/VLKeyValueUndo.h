//
//  VLKeyValueUndo.h
//  Vocalese
//
//  Created by Matthias Neeracher on 12/3/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface VLKeyValueUndo : NSObject {
	id				owner;
	NSDictionary *	keysAndNames;
}

- (id)initWithOwner:(id)owner keysAndNames:(NSDictionary *)keysAndNames;

@end
