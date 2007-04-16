//
//  VLKeyValueUndo.mm
//  Vocalese
//
//  Created by Matthias Neeracher on 12/3/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "VLKeyValueUndo.h"


@implementation VLKeyValueUndo

- (id)initWithOwner:(id)o keysAndNames:(NSDictionary *)kn
{
	owner			= o;
	keysAndNames	= [kn retain];

	[owner addObserver:self];
	for (NSEnumerator * e = [keysAndNames keyEnumerator];
		 NSString * key = [e nextObject];
	)
		[owner addObserver:self forKeyPath:key 
			   options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew
			   context:[keysAndNames objectForKey:key]];

	return self;
}

- (void)removeObservers:(id)target
{
	for (NSEnumerator * e = [keysAndNames keyEnumerator];
		 NSString * key = [e nextObject];
	)
		[target removeObserver:self forKeyPath:key];
}

- (void) dealloc
{
	[keysAndNames release];
	[super dealloc];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	id	oldVal	= [change objectForKey:NSKeyValueChangeOldKey];
	id 	newVal = [change objectForKey:NSKeyValueChangeNewKey];

	if (![oldVal isEqual:newVal]) {	
		NSUndoManager * undo = [owner undoManager];
		NSString *		name = [keysAndNames objectForKey:keyPath];
		[undo registerUndoWithTarget:owner selector:@selector(setValuesForKeysWithDictionary:) 
			object: [NSDictionary dictionaryWithObjectsAndKeys: oldVal, keyPath, nil]];
		[undo setActionName: name];
	}
}

@end
