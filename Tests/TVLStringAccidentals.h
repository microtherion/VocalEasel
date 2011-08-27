//
//  TVLStringAccidentals.h
//  VocalEasel
//
//  Created by Matthias Neeracher on 8/27/11.
//  Copyright 2011 Apple Computer. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (TVLStringAccidentals)

- (NSString *)sharp;
- (NSString *)flat;
- (NSString *)natural;
- (NSString *)doubleSharp;
- (NSString *)doubleFlat;
- (NSString *)flat5;
- (NSString *)sharp5;
- (NSString *)flat9;
- (NSString *)sharp9;
- (NSString *)sharp11;
- (NSString *)flat13;

@end
