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

- (NSString *)flat5
{
    return [[self flat] stringByAppendingString:@"5"];
}

- (NSString *)sharp5
{
    return [[self sharp] stringByAppendingString:@"5"];
}

- (NSString *)flat9
{
    return [[self flat] stringByAppendingString:@"9"];    
}

- (NSString *)sharp9
{
    return [[self sharp] stringByAppendingString:@"9"];
}

- (NSString *)sharp11
{
    return [[self sharp] stringByAppendingString:@"11"];
}

- (NSString *)flat13
{
    return [[self flat] stringByAppendingString:@"13"];
}

@end
