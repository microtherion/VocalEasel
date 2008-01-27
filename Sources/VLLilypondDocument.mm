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

#import <algorithm>

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

static NSSize 		sPaperSizes[] = {
	{842.0f, 1191.0f}, {595.0f, 842.0f}, {421.0f, 595.0f}, {298.0f, 421.0f},
	{612.0f, 1008.0f}, {612.0f, 792.0f}, {792.0f, 1224.0f}
};
static const char * 	sPaperNames[] = {
	"a3", "a4", "a5", "a6", "letter", "legal", "11x17", 0
};

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
	NSPrintInfo *	pi			= [self printInfo];
	NSSize 			sz 			= [pi paperSize];
	int    			bestPaper 	= -1;
	float			bestDist    = 1e10f;
	
	if ([pi orientation] == NSLandscapeOrientation)
		std::swap(sz.width, sz.height);

	for (int paper = 0; sPaperNames[paper]; ++paper) {
		float dist = hypotf(sz.width - sPaperSizes[paper].width,
							sz.height- sPaperSizes[paper].height);
		if (dist < bestDist) {
			bestPaper 	= paper;
			bestDist	= dist;
		}
	}

	NSString * paper = [NSString stringWithFormat:
	  [pi orientation] == NSLandscapeOrientation ? @"\"%s\" 'landscape" : @"\"%s\"", 
	  sPaperNames[bestPaper]];
	float 	  scaling= [[[pi dictionary] objectForKey:NSPrintScalingFactor]
						   floatValue];

	[ly substituteMacro:@"TITLE" withValue:songTitle];
	[ly substituteMacro:@"POET" withValue:songLyricist];
	[ly substituteMacro:@"COMPOSER" withValue:songComposer];
	[ly substituteMacro:@"ARRANGER" withValue:songArranger];
	[ly substituteMacro:@"VLVERSION" withValue:
			[bndl objectForInfoDictionaryKey:@"CFBundleVersion"]];
	[ly substituteMacro:@"PAPERSIZE" withValue:paper];
	//	[ly substituteMacro:@"FORMATTING" withValue:@"ragged-last-bottom = ##f"];
	[ly substituteMacro:@"VLVERSION" withValue:
			[bndl objectForInfoDictionaryKey:@"CFBundleVersion"]];
	[ly substituteMacro:@"CHORDSIZE" withValue:
			[NSString stringWithFormat:@"%f", chordSize]];
	[ly substituteMacro:@"LYRICSIZE" withValue:
			[NSString stringWithFormat:@"%f", lyricSize]];
	[ly substituteMacro:@"STAFFSIZE" withValue:
			[NSString stringWithFormat:@"%f", staffSize*scaling]];
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
