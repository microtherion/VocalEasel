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
	NSArray * nodes = [self nodesForXPath:path error:outError];
	return [nodes count] ? [nodes objectAtIndex:0] : nil;
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

- (NSXMLElement *) identificationElement
{
	NSXMLElement *	identification = [NSXMLNode elementWithName:@"identification"];
	NSXMLElement * 	composer = [NSXMLNode elementWithName:@"creator"
										  stringValue:songComposer];
	[composer addAttribute: [NSXMLNode attributeWithName:@"type"
									   stringValue:@"composer"]];
	[identification addChild:composer];
	NSXMLElement * 	poet = [NSXMLNode elementWithName:@"creator"
									  stringValue:songLyricist];
	[poet addAttribute: [NSXMLNode attributeWithName:@"type"
									   stringValue:@"poet"]];
	[identification addChild:poet];

	NSXMLElement * encoding = [NSXMLNode elementWithName:@"encoding"];
	[encoding addChild: 
		[NSXMLNode elementWithName:@"encoding-date"
				   stringValue:
					   [[NSDate date] 
						   descriptionWithCalendarFormat:@"%Y-%m-%d"
						   timeZone:nil locale:nil]]];
	[encoding addChild:
		[NSXMLNode elementWithName:@"software"
				   stringValue: [NSString stringWithFormat:@"VocalEasel %@",
					  [[NSBundle mainBundle] 
						  objectForInfoDictionaryKey:@"CFBundleVersion"]]]];
	[identification addChild:encoding];

	return identification;
}

- (NSData *)XMLDataWithError:(NSError **)outError
{
	NSXMLElement  * work = [NSXMLNode elementWithName:@"work"];
	[work addChild: [NSXMLNode elementWithName:@"work-title"
							   stringValue:songTitle]];
	
	NSXMLElement *	identification = [self identificationElement];

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
			children:[NSArray arrayWithObjects: work, identification, 
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

- (NSFileWrapper *)XMLFileWrapperWithError:(NSError **)outError flat:(BOOL)flat;
{
	NSData * contents = [self XMLDataWithError:outError];
	
	if (!contents) {
		return nil;
	} else if (flat) {
		return [[[NSFileWrapper alloc] 
					initRegularFileWithContents:contents]
				   autorelease];
	} else {
		NSFileWrapper * wrap 	= [[[NSFileWrapper alloc]
									  initDirectoryWithFileWrappers:
										  [NSDictionary dictionary]]
									  autorelease];
		[wrap addRegularFileWithContents:contents
			  preferredFilename:@"Song"];

		return wrap;
	}
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

int8_t sStepToPitch[] = {
	9, 11, 0, 2, 4, 5, 7
};

- (VLNote) readNote:(NSXMLElement*)note withUnit:(VLFraction)unit
{
	NSError *	outError;
	VLNote		n;
	
	n.fTied = 0;

	if ([[note elementsForName:@"rest"] count]) {
		n.fPitch  = VLNote::kNoPitch;
	} else {
		n.fPitch  = ([note intForXPath:@"./pitch/octave" error:&outError]+1)*12;
		n.fPitch += 
			sStepToPitch[[[note stringForXPath:@"./pitch/step" error:&outError]
							 characterAtIndex:0] - 'A'];
		if (NSXMLElement * alter = [note nodeForXPath:@"./pitch/alter" error:&outError])
			n.fPitch += [[alter stringValue] intValue];
	}
	n.fDuration = VLFraction([note intForXPath:@"./duration" error:&outError])*unit;

	return n;
}

- (void) readMelody:(NSArray *)measures error:(NSError **)outError
{
	NSEnumerator * e = [measures objectEnumerator];
	
	for (NSXMLElement * measure; measure = [e nextObject]; ) {
		VLProperties & 	prop = song->fProperties.front();
		VLFraction		unit(1, 4*prop.fDivisions);
		VLFraction		at(0);
		int				m = [[[measure attributeForName:@"number"]
								 stringValue] intValue]-1;

		if (m >= song->CountMeasures())
			song->fMeasures.resize(m);

		NSEnumerator * n = [[measure elementsForName:@"note"] objectEnumerator];

		for (NSXMLElement * note; note = [n nextObject]; ) {
			VLNote n = [self readNote:note withUnit:unit];
			if (n.fPitch != VLNote::kNoPitch)
				song->AddNote(n, m, at);
			at += n.fDuration;
		}
	}
}

- (void) readChords:(NSArray *)measures error:(NSError **)outError
{
	NSEnumerator * e = [measures objectEnumerator];
	
	for (NSXMLElement * measure; measure = [e nextObject]; ) {
		VLProperties & 	prop = song->fProperties.front();
		VLFraction		unit(1, 4*prop.fDivisions);
		VLFraction		at(0);
		VLFraction		dur(0);
		int				m = [[[measure attributeForName:@"number"]
								 stringValue] intValue]-1;
		VLChord			chord;

		chord.fSteps	= 0;
		if (m >= song->CountMeasures())
			song->fMeasures.resize(m);

		NSEnumerator * n = [[measure elementsForName:@"note"] objectEnumerator];

		for (NSXMLElement * note; note = [n nextObject]; ) {
			VLNote n = [self readNote:note withUnit:unit];
			if (![[note elementsForName:@"chord"] count]) {
				//
				// Start of new chord
				//
				if (chord.fSteps)
					song->AddChord(chord, m, at);
				at 			   += dur;
				chord.fPitch	= n.fPitch;
				chord.fRootPitch= VLNote::kNoPitch;
				chord.fDuration	= n.fDuration;
				chord.fSteps 	= n.fPitch == VLNote::kNoPitch ? 0 : VLChord::kmUnison;
				dur			 	= n.fDuration;
				if (n.fPitch < VLNote::kMiddleC) {
					chord.fPitch	= VLNote::kNoPitch;
					chord.fRootPitch= n.fPitch;
				}
			} else if (chord.fPitch == VLNote::kNoPitch) {
				chord.fPitch	= n.fPitch;
			} else {
				chord.fSteps   |= 1 << (n.fPitch-chord.fPitch);
			}
		}
		if (chord.fSteps)
			song->AddChord(chord, m, at);
	}
}

- (BOOL)readFromXMLData:(NSData *)data error:(NSError **)outError
{
	NSXMLDocument * doc 	= [[NSXMLDocument alloc] initWithData:data
													 options:0
													 error:outError];
	//
	// For now, in gross violation of MusicXML spirit, we're only reading 
	// our own input.
	//
	songTitle	= [[doc stringForXPath:@".//work-title" error:outError] retain];
	songComposer= [[doc stringForXPath:@".//creator[@type=\"composer\"]" 
						error: outError] retain];
	songLyricist= [[doc stringForXPath:@".//creator[@type=\"poet\"]" 
					   error: outError] retain];

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
	
	[self readMelody:[melody nodesForXPath:@"./measure" error:outError] 
		  error:outError];
	[self readChords:[chords nodesForXPath:@"./measure" error:outError]
		  error:outError];

	return YES;
}

- (BOOL)readFromXMLFileWrapper:(NSFileWrapper *)wrapper error:(NSError **)outError
{
	return [self readFromXMLData: [[[wrapper fileWrappers] objectForKey:@"Song"]
									  regularFileContents]	
				 error:outError];
}

@end
