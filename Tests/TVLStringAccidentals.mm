//
//  TVLStringAccidentals.mm
//  VocalEasel
//
//  Created by Matthias Neeracher on 8/27/11.
//  Copyright 2011 Apple Computer. All rights reserved.
//

#import "TVLStringAccidentals.h"
#import "VLPitchName.h"

@implementation NSString (TVLStringAccidentals)

- (NSString *)sharp
{
    return [self stringByAppendingString:[NSString stringWithUTF8String:kVLSharpStr]];
}
            
- (NSString *)flat
{
    return [self stringByAppendingString:[NSString stringWithUTF8String:kVLFlatStr]];
    
}

- (NSString *)natural
{
    return [self stringByAppendingString:[NSString stringWithUTF8String:kVLNaturalStr]];
}

- (NSString *)doubleSharp
{
    return [self stringByAppendingString:[NSString stringWithUTF8String:kVL2SharpStr]];
}

- (NSString *)doubleFlat
{
    return [self stringByAppendingString:[NSString stringWithUTF8String:kVL2FlatStr]];
}

@end
