//
// File: VLPListDocument.h - Convert document from and to Cocoa plist
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2007 Matthias Neeracher
//

#import <Cocoa/Cocoa.h>
#import "VLDocument.h"

//
// To convert from and to complex file formats, we use ruby scripts operating
// on the XML representation of a Cocoa property list. The property list 
// representation is strictly intended as an intermediate representation, 
// subject to change as necessary.
//
@interface VLDocument (Plist) 

- (id)plistInPerformanceOrder:(BOOL)performanceOrder;
- (BOOL)readFromPlist:(id)plist error:(NSError **)outError;
- (NSFileWrapper *)fileWrapperWithFilter:(NSString *)filterName
								   error:(NSError **)outError;
- (BOOL)readFromFileWrapper:(NSFileWrapper *)wrapper
				 withFilter:(NSString *)filterName
					  error:(NSError **)outError;

- (IBAction) dump:(id)sender;

@end
