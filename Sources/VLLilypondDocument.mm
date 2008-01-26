//
// File: VLLilypondDocument.mm - Export document in LilyPond format
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2006-2007 Matthias Neeracher
//

#import "VLLilypondDocument.h"
#import "VLLilypondWriter.h"

@interface NSMutableString (VLLilypond)

- (void) substituteMacro:(NSString *)macro withValue:(NSString *)value;
- (void) purgeMacros;

@end

@implementation NSMutableString (VLLilypond)

- (void) substituteMacro:(NSString *)m withValue:(NSString *)value repeat:(BOOL)repeat
{
	if ([value isEqual:@""])
		return;
	NSString * 	macro = [NSString stringWithFormat:@"<{%@}>", m];
	NSRange		range = 
		[value rangeOfCharacterFromSet:
				   [NSCharacterSet characterSetWithCharactersInString:@"\n"]];
	BOOL 		hasEOL= range.location != NSNotFound;
	unsigned	from  = 0;

	for (range = [self rangeOfString:macro];
		 range.location != NSNotFound;
		 range = [self rangeOfString:macro options:0 
					   range:NSMakeRange(from, [self length]-from)]
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
			NSString * nl;
			if ([nonBlank length]) {
				NSRange nb 		= [pfxStr rangeOfString:nonBlank];
				prefix.length	= nb.location;
				pfxStr			= 
					[[self substringWithRange:prefix]
						stringByAppendingString:@"  "];
				sfxStr			= [NSString stringWithFormat:@"\n%@", pfxStr];
				nl				= @"\n";
			} else {
				range 			= line;
				nl				= @"";
			}
			NSArray * lines 	= [value componentsSeparatedByString:@"\n"];
			value	= 
				[NSString stringWithFormat:@"%@%@%@%@", nl, pfxStr,
						  [lines componentsJoinedByString:
									 [@"\n" stringByAppendingString:pfxStr]],
						  sfxStr];
		}
		from = range.location + [value length];
		if (repeat) {
			NSRange line = [self lineRangeForRange:range];
			[self insertString:[self substringWithRange:line]
				  atIndex:line.location+line.length];
			from 	= line.location+2*line.length+[value length]-range.length;
		}
		[self replaceCharactersInRange:range withString:value];
	}
}


- (void)substituteMacro:(NSString*)macro withValue:(NSString*)value
{
	[self substituteMacro:macro withValue:value repeat:NO];
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
	VLLilypondWriter        writer;
	writer.Visit(*song);
	NSBundle *	 			bndl = [NSBundle mainBundle];
	NSString * 				tmpl = 
		[bndl pathForResource:lilypondTemplate
			  ofType:@"lyt" inDirectory:@"Templates"];
	NSStringEncoding		enc = NSUTF8StringEncoding;
	NSMutableString * 		ly = 
		[NSMutableString stringWithContentsOfFile:tmpl encoding:enc error:outError];
	[ly substituteMacro:@"TITLE" withValue:songTitle];
	[ly substituteMacro:@"POET" withValue:songLyricist];
	[ly substituteMacro:@"COMPOSER" withValue:songComposer];
	[ly substituteMacro:@"ARRANGER" withValue:songArranger];
	[ly substituteMacro:@"VLVERSION" withValue:
			[bndl objectForInfoDictionaryKey:@"CFBundleVersion"]];
	[ly substituteMacro:@"PAPERSIZE" withValue:@"letter"];
	[ly substituteMacro:@"FORMATTING" withValue:@"ragged-last-bottom = ##f"];
	[ly substituteMacro:@"VLVERSION" withValue:
			[bndl objectForInfoDictionaryKey:@"CFBundleVersion"]];
	[ly substituteMacro:@"CHORDS" withValue: 
			[NSString stringWithUTF8String:writer.Chords().c_str()]];
	[ly substituteMacro:@"NOTES" withValue: 
			[NSString stringWithUTF8String:writer.Melody().c_str()]];
	if (size_t stanzas = song->CountStanzas())
		for (size_t s=0; s<stanzas; ++s) {
			[ly substituteMacro:@"LYRICS" withValue:
					[NSString stringWithUTF8String:writer.Lyrics(s).c_str()]
				repeat: s<stanzas];
		}
	[ly purgeMacros];
	return [ly dataUsingEncoding:enc];
}

- (NSFileWrapper *)lilypondFileWrapperWithError:(NSError **)outError
{
	NSData * data = [self lilypondDataWithError:outError];
	
	if (!data)
		return nil;
	else
		return [[[NSFileWrapper alloc] 
					initRegularFileWithContents:data]
				   autorelease];
}

@end
