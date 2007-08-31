//
// File: VLXMLDocument.mm - Read and write native (MusicXML) document format
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2006-2007 Matthias Neeracher
//

#import "VLXMLDocument.h"
#import "VLPListDocument.h"

@implementation VLDocument (XML)


- (NSArray *)propertyKeys
{
	static NSArray * sPropertyKeys = nil;
	
	if (!sPropertyKeys)
		sPropertyKeys = [[NSArray alloc] initWithObjects:
											 @"songGroove", @"songTempo", nil];

	return sPropertyKeys;
}

- (NSFileWrapper *)XMLFileWrapperWithError:(NSError **)outError flat:(BOOL)flat;
{
	NSFileWrapper * contents = [self fileWrapperWithFilter:@"VLMusicXMLType" error:outError];
	
	if (!contents) {
		return nil;
	} else if (flat) {
		return contents;
	} else {
		NSFileWrapper * wrap 	= [[[NSFileWrapper alloc]
									  initDirectoryWithFileWrappers:
										  [NSDictionary dictionary]]
									  autorelease];
		[contents setPreferredFilename:@"Song"];
		[wrap addFileWrapper:contents];
		NSDictionary * prop = 
			[self dictionaryWithValuesForKeys:[self propertyKeys]];
		[wrap addRegularFileWithContents:
				  [NSPropertyListSerialization dataFromPropertyList:prop
											   format:NSPropertyListXMLFormat_v1_0
											   errorDescription:nil]
			  preferredFilename:@"Properties"];
		if (vcsWrapper)
			[wrap addFileWrapper:vcsWrapper];

		return wrap;
	}
}

- (BOOL)readFromXMLFileWrapper:(NSFileWrapper *)wrapper error:(NSError **)outError
{
	NSDictionary * wrappers = [wrapper fileWrappers];
	if ((vcsWrapper = [wrappers objectForKey:@"CVS"])
     || (vcsWrapper = [wrappers objectForKey:@".svn"])
	)
		[vcsWrapper retain];
	NSFileWrapper * prop = [wrappers objectForKey:@"Properties"];
	if (prop) {
		NSUndoManager * undoMgr = [self undoManager];
		[undoMgr disableUndoRegistration];
		[self setValuesForKeysWithDictionary:
				  [NSPropertyListSerialization 
					  propertyListFromData:[prop regularFileContents]
					  mutabilityOption:NSPropertyListImmutable
					  format:nil errorDescription:nil]];
		[undoMgr enableUndoRegistration];
	}
	return [self readFromFileWrapper:[wrappers objectForKey:@"Song"] withFilter:@"VLMusicXMLType"	
				 error:outError];
}

@end
