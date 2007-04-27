//
// File: VLPitchTransformer.h - Bindings helper for MIDI pitch
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2006-2007 Matthias Neeracher
//

#import <Cocoa/Cocoa.h>

@interface VLPitchTransformer : NSValueTransformer {
}

+ (Class)transformedValueClass;

- (NSString *)transformedValue:(id)value;

@end
