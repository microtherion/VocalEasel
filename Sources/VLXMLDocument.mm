//
//  VLXMLDocument.mm
//  Vocalese
//
//  Created by Matthias Neeracher on 10/10/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "VLXMLDocument.h"

@interface NSXMLNode (VLConvenience)

- (id) nodeForXPath:(NSString *)path error:(NSError **)outError;
- (NSString *)stringForXPath:(NSString *)path error:(NSError **)outError;
- (int)intForXPath:(NSString *)path error:(NSError **)outError;

@end

@implementation NSXMLNode (VLConvenience)

- (id) nodeForXPath:(NSString *)path error:(NSError **)outError
{
	return [[self nodesForXPath:path error:outError] objectAtIndex:0];
}

- (NSString *)stringForXPath:(NSString *)path error:(NSError **)outError
{
	return [[self nodeForXPath:path error:outError] stringValue];
}

- (int)intForXPath:(NSString *)path error:(NSError **)outError
{
	return [[[self nodeForXPath:path error:outError] stringValue] intValue];
}

@end

@implementation VLDocument (XML)

- (NSXMLDTD *)partwiseDTD
{
	NSString * dtdPath = [[NSBundle mainBundle] pathForResource:@"partwise"
												ofType:@"dtd"
												inDirectory:@"DTD"];
	NSXMLDTD * dtd = [[[NSXMLDTD alloc]
						  initWithContentsOfURL:[NSURL fileURLWithPath:dtdPath]
						  options:0 error:nil]
						 autorelease];
	[dtd setPublicID:@"-//Recordare//DTD MusicXML 1.1 Partwise//EN"];
	[dtd setSystemID:@"http://www.musicxml.org/dtds/partwise.dtd"];
	[dtd setName:@"score-partwise"];

	return dtd;
}

- (NSXMLElement *)scorePartWithID:(NSString *)id name:(NSString *)name
{
	NSXMLElement * part = [NSXMLNode elementWithName:@"score-part"];
	[part addAttribute: [NSXMLNode attributeWithName:@"id" 
								   stringValue:id]];
	[part addChild: [NSXMLNode elementWithName:@"part-name"
							   stringValue:name]];

	return part;
}

- (NSXMLElement *)attributesWithProps:(VLProperties)props
{
	NSXMLElement * attr = [NSXMLNode elementWithName:@"attributes"];
	[attr addChild: [NSXMLNode elementWithName:@"divisions"
							   stringValue:[NSString stringWithFormat:@"%d",
													 props.fDivisions]]];

	NSXMLElement * key	= [NSXMLNode elementWithName:@"key"];
	[key addChild: [NSXMLNode elementWithName:@"fifths"
							  stringValue:[NSString stringWithFormat:@"%d",
													props.fKey]]];
	[key addChild: [NSXMLNode elementWithName:@"mode"
							  stringValue:
								  props.fMode < 0 ? @"minor" : @"major"]];

	NSXMLElement * time = [NSXMLNode elementWithName:@"time"];
	[time addChild: [NSXMLNode elementWithName:@"beats"
							   stringValue:[NSString stringWithFormat:@"%d",
													 props.fTime.fNum]]];
	[time addChild: [NSXMLNode elementWithName:@"beat-type"
							   stringValue:[NSString stringWithFormat:@"%d",
													 props.fTime.fDenom]]];
	
	NSXMLElement * clef = [NSXMLNode elementWithName:@"clef"];
	[clef addChild: [NSXMLNode elementWithName:@"sign"
							   stringValue:@"G"]];
	[clef addChild: [NSXMLNode elementWithName:@"line"
							   stringValue:@"2"]];
	
	
	[attr addChild: key];
	[attr addChild: time];
	[attr addChild: clef];

	return attr;
}

const char * sSteps = "C DbD EbE F GbG AbA BbB ";

- (NSXMLElement *)noteWithPitch:(int)pitch duration:(int)units useSharps:(BOOL)useSharps
{
	NSXMLElement * note = [NSXMLNode elementWithName:@"note"];
	if (pitch == VLNote::kNoPitch) {
		[note addChild: [NSXMLNode elementWithName:@"rest"]];
	} else {
		NSXMLElement * 	p 		= [NSXMLNode elementWithName:@"pitch"];
		int 			octave 	= pitch/12 - 1;
		pitch					= 2*(pitch % 12);
		char 			step	= sSteps[pitch];
		int 			alt		= sSteps[pitch+1] == 'b';
		if (alt)
			if (useSharps) {
				--step; // Db -> C#
				alt = 1;
			} else {
				alt = -1;
			}
		[p addChild: 
			   [NSXMLNode elementWithName:@"step"
						  stringValue: [NSString stringWithFormat:@"%c",
												 step]]];
		if (alt)
			[p addChild: 
				   [NSXMLNode elementWithName:@"alter"
							  stringValue: [NSString stringWithFormat:@"%d",
													 alt]]];
		[p addChild: 
			   [NSXMLNode elementWithName:@"octave"
						  stringValue: [NSString stringWithFormat:@"%d",
												 octave]]];			
		[note addChild:p];
	}
	[note addChild: [NSXMLNode elementWithName:@"duration"
							   stringValue: [NSString stringWithFormat:@"%d",	
													  units]]];
	[note addChild: [NSXMLNode elementWithName:@"voice"
							   stringValue: @"1"]];

	return note;
}

- (void)addNotes:(VLNoteList *)notes toMeasure:(NSXMLElement *)meas
{
	VLFraction	resolution(1, song->fProperties.front().fDivisions*4);
	bool		useSharps = song->fProperties.front().fKey > 0;
	for (VLNoteList::const_iterator note = notes->begin(); 
		 note != notes->end();	
		 ++note
	) {
		VLFraction 	u 		= note->fDuration / resolution;
		int			units	= (u.fNum+u.fDenom/2)/u.fDenom;
		[meas addChild:[self noteWithPitch:note->fPitch duration:units useSharps:useSharps]];
	}			 
}

- (void)addChords:(VLChordList *)chords toMeasure:(NSXMLElement *)meas
{
	VLFraction	resolution(1, song->fProperties.front().fDivisions*4);
	bool		useSharps = song->fProperties.front().fKey > 0;
	for (VLChordList::const_iterator chord = chords->begin(); 
		 chord != chords->end();	
		 ++chord
	) {
		VLFraction 		u 		= chord->fDuration / resolution;
		int				units	= (u.fNum+u.fDenom/2)/u.fDenom;
		NSXMLElement*	ch   	= nil;
		if (chord->fPitch == VLNote::kNoPitch) {
			[meas addChild:[self noteWithPitch:chord->fPitch duration:units useSharps:useSharps]];
			continue;
		}
		if (chord->fRootPitch != VLNote::kNoPitch) {
			[meas addChild:[self noteWithPitch:chord->fRootPitch
								 duration:units useSharps:useSharps]];
			ch = [NSXMLNode elementWithName:@"chord"];
		}
		for (int step=0; step<32; ++step)
			if ((1 << step) > chord->fSteps) {
				break;
			} else if (chord->fSteps & (1 << step)) {
				NSXMLElement * note = 
					[self noteWithPitch:chord->fPitch+step
						  duration:units useSharps:useSharps];
				[note insertChild:ch atIndex:0];
				[meas addChild: note];
				ch = [NSXMLNode elementWithName:@"chord"];
			}
	}			 
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
	NSXMLElement  * partList = [NSXMLNode elementWithName:@"part-list"];
	[partList addChild: [self scorePartWithID:@"HARM" name:@"Chords"]];
	[partList addChild: [self scorePartWithID:@"MELO" name:@"Melody"]];

	NSXMLElement  * chords = [NSXMLNode elementWithName:@"part"];
	[chords addAttribute: [NSXMLNode attributeWithName:@"id"
									 stringValue:@"HARM"]];

	NSXMLElement  * melody = [NSXMLNode elementWithName:@"part"];
	[melody addAttribute: [NSXMLNode attributeWithName:@"id"
										   stringValue:@"MELO"]];

	for (int measure = 0; measure < song->CountMeasures(); ++measure) {
		NSXMLElement * melMeas = [NSXMLNode elementWithName:@"measure"];
		[melMeas addAttribute: 
					 [NSXMLNode attributeWithName:@"number"
								stringValue:[NSString stringWithFormat:@"%d",
													  measure+1]]];
		if (!measure)
			[melMeas addChild:
						 [self attributesWithProps:song->fProperties.front()]];

		NSXMLElement * harMeas = [melMeas copy];
		
		[self addNotes:&song->fMeasures[measure].fMelody toMeasure:melMeas];
		[self addChords:&song->fMeasures[measure].fChords toMeasure:harMeas];

		[melody addChild:melMeas];
		[chords addChild:harMeas];
	}

	NSXMLElement  * score = 
		[NSXMLNode 
			elementWithName:@"score-partwise" 
			children:[NSArray arrayWithObjects: 
								  partList, chords, melody, nil]
			attributes:[NSArray arrayWithObject:
									[NSXMLNode attributeWithName:@"version"
											   stringValue:@"1.1"]]];
	NSXMLDocument * doc = [[[NSXMLDocument alloc]
							   initWithRootElement:score]
							  autorelease];
	[doc setVersion:@"1.0"];
	[doc setCharacterEncoding:@"UTF-8"];
	[doc setDTD:[self partwiseDTD]];
	[[doc DTD] setChildren: nil];

	return [doc XMLDataWithOptions:NSXMLNodePrettyPrint|NSXMLNodeCompactEmptyElement];
}

- (BOOL)readPropsFromAttributes:(NSXMLElement*)attr error:(NSError **)outError
{
	VLProperties & prop = song->fProperties.front();

	prop.fDivisions		= [attr intForXPath:@"./divisions" error:outError];
	prop.fKey			= [attr intForXPath:@"./key/fifths" error:outError];
	prop.fMode			= [[attr stringForXPath:@"./key/mode" error:outError]
						  isEqual:@"minor"] ? -1 : 1;
	prop.fTime.fNum		= [attr intForXPath:@"./time/beats" error:outError];
	prop.fTime.fDenom	= [attr intForXPath:@"./time/beat-type" error:outError];
	
	return YES;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
	NSXMLDocument * doc 	= [[NSXMLDocument alloc] initWithData:data
													 options:0
													 error:outError];
	//
	// For now, in gross violation of MusicXML spirit, we're only reading 
	// our own input.
	//
	NSXMLElement * chords	= [doc nodeForXPath:@".//part[@id=\"HARM\"]" 
								   error:outError];
	NSXMLElement * melody	= [doc nodeForXPath:@".//part[@id=\"MELO\"]" 
								   error:outError];

	if (!chords || !melody)
		return NO;
	if (![self readPropsFromAttributes:
				   [melody nodeForXPath:@".//attributes" error:outError]
			   error:outError]
	)
		return NO;
		
	return YES;
}

@end
