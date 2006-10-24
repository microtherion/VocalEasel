//
//  VLPitchTransformer.mm
//  Vocalese
//
//  Created by Matthias Neeracher on 10/23/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "VLPitchTransformer.h"
#import "VLModel.h"

@implementation VLPitchTransformer

+ (Class)transformedValueClass
{
	return [NSString class];
}

const char * sPitch2Name = "C D EF G A B";

- (NSString *)transformedValue:(id)value
{
	int pitch = [value intValue];
	int octave= (pitch / 12)-1;
	pitch %= 12;
	if (sPitch2Name[pitch] == ' ')
		return [NSString stringWithFormat:@"%c%C%d / %c%C%d", 
						 sPitch2Name[pitch-1], kVLSharpChar, octave, 
						 sPitch2Name[pitch+1], kVLFlatChar, octave];
	else
		return [NSString stringWithFormat:@"%c%d",
						 sPitch2Name[pitch], octave];
}

@end
