//
// File: VLKeyValueUndo.mm - Automatically handle undo functionality for 
//                          key-value paths
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2007-2011 Matthias Neeracher
//

#import "VLKeyValueUndo.h"
#import "VLDocument.h"

@implementation VLKeyValueUndo

- (id)initWithOwner:(id)o keysAndNames:(NSDictionary *)kn update:(VLKeyValueUpdateHook)hook
{
	owner			= o;
	keysAndNames	= [kn retain];
    updateHook      = Block_copy(hook);

	for (NSEnumerator * e = [keysAndNames keyEnumerator];
		 NSString * key = [e nextObject];
	)
		[owner addObserver:self forKeyPath:key 
			   options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew
			   context:[keysAndNames objectForKey:key]];
		
	return self;
}

- (id)initWithOwner:(id)o keysAndNames:(NSDictionary *)kn
{
    return [self initWithOwner:o keysAndNames:kn update:nil];
}

- (void) dealloc
{
	for (NSEnumerator * e = [keysAndNames keyEnumerator];
		 NSString * key = [e nextObject];
    )
		[owner removeObserver:self forKeyPath:key];
	[keysAndNames release];
    [updateHook release];
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
        if (updateHook)
            updateHook(keyPath);
	}
}

@end
