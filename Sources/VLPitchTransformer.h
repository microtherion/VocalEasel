//
//  VLPitchTransformer.h
//  Vocalese
//
//  Created by Matthias Neeracher on 10/23/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface VLPitchTransformer : NSValueTransformer {
}

+ (Class)transformedValueClass;

- (NSString *)transformedValue:(id)value;

@end
