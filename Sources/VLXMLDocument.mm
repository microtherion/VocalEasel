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
		if (vcsWrapper)
			[wrap addFileWrapper:vcsWrapper];

		return wrap;
	}
}

- (BOOL)readFromXMLFileWrapper:(NSFileWrapper *)wrapper error:(NSError **)outError
{
	if ([wrapper isDirectory]) {
		NSDictionary * wrappers = [wrapper fileWrappers];
		if ((vcsWrapper = [wrappers objectForKey:@"CVS"])
		 || (vcsWrapper = [wrappers objectForKey:@".svn"])
		)
			[vcsWrapper retain];
		//
		// Read properties dictionary for backward compatibility
		//
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
	} else {
		if ([self readFromFileWrapper:wrapper withFilter:@"VLMusicXMLType" error:outError]) {
			[self setFileURL:nil];
			
			return YES;
		} else
			return NO;
	}
}

@end
