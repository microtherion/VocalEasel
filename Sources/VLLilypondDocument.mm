//
//  VLLilypondDocument.mm
//  Vocalese
//
//  Created by Matthias Neeracher on 10/20/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "VLLilypondDocument.h"

@interface NSMutableString (VLLilypond)

- (void) substituteMacro:(NSString *)macro withValue:(NSString *)value;
- (void) purgeMacros;

@end

@implementation NSMutableString (VLLilypond)

- (void) substituteMacro:(NSString *)m withValue:(NSString *)value
{
	NSString * 	macro = [NSString stringWithFormat:@"<{%@}>", m];
	NSRange		range = 
		[value rangeOfCharacterFromSet:
				   [NSCharacterSet characterSetWithCharactersInString:@"\n"]];
	BOOL 		hasEOL= range.location != NSNotFound;

	for (range = [self rangeOfString:macro];
		 range.location != NSNotFound;
		 range = [self rangeOfString:macro]
	) {
		if (hasEOL) {
			//
			// Multi line substitution, figure out a prefix
			//
			NSRange prefix, suffix;
			NSRange line 		= [self lineRangeForRange:range];
			suffix.location 	= range.location+range.length;
			suffix.length		= line.location+line.length-suffix.location;
			prefix.location		= line.location;
			prefix.length		= range.location-prefix.location;
			NSString * pfxStr	= [self substringWithRange:prefix];
			NSString * nonBlank	= 
				[pfxStr stringByTrimmingCharactersInSet:
							[NSCharacterSet whitespaceCharacterSet]];
			NSString * sfxStr   = 
				[[self substringWithRange:suffix]
					stringByTrimmingCharactersInSet:
						[NSCharacterSet whitespaceCharacterSet]];
			if ([nonBlank length]) {
				NSRange nb 		= [pfxStr rangeOfString:nonBlank];
				prefix.length	= nb.location - prefix.location;
				pfxStr			= 
					[[self substringWithRange:prefix]
						stringByAppendingString:@"  "];
				sfxStr			= [NSString stringWithFormat:@"\n%@", pfxStr];
			} else {
				range 			= line;
			}
			NSArray * lines 	= [value componentsSeparatedByString:@"\n"];
			value	= 
				[NSString stringWithFormat:@"%@%@%@", pfxStr,
						  [lines componentsJoinedByString:
									 [@"\n" stringByAppendingString:pfxStr]],
						  sfxStr];
		}
		[self replaceCharactersInRange:range withString:value];
	}
}

- (void) purgeMacros
{
	for (NSRange range = [self rangeOfString:@"<{"]; 
		 range.location != NSNotFound;
		 range = [self rangeOfString:@"<{"]
	) 
		[self replaceCharactersInRange:[self lineRangeForRange:range] 
			  withString: @""];
}

@end

@implementation VLDocument (Lilypond)

- (NSData *)lilypondDataWithError:(NSError **)outError
{
	NSBundle *	 		bndl = [NSBundle mainBundle];
	NSString * 			tmpl = 
		[bndl pathForResource:lilypondTemplate
			  ofType:@"lyt" inDirectory:@"Templates"];
	NSStringEncoding	enc = NSUTF8StringEncoding;
	NSError *			err;
	NSMutableString * 	ly = 
		[[NSString stringWithContentsOfFile:tmpl encoding:enc error:&err]
			mutableCopy];
	[ly substituteMacro:@"VLVERSION" withValue:
			[bndl objectForInfoDictionaryKey:@"CFBundleVersion"]];
	[ly purgeMacros];
	return [ly dataUsingEncoding:enc];
}

@end
