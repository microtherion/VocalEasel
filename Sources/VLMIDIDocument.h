//
// File: VLMIDIDocument.h - Export document in MIDI format
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2006-2007 Matthias Neeracher
//

#import <Cocoa/Cocoa.h>
#import "VLDocument.h"

@interface VLDocument (MIDI)

- (NSFileWrapper *)midiFileWrapperWithError:(NSError **)outError;

@end
