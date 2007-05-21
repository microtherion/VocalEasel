//
// File: VLXMLDocument.mm - Read and write native (MusicXML) document format
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2006-2007 Matthias Neeracher
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
	NSXMLDTD * dtd = [[[NSXMLDTD alloc] init] autorelease];
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

- (NSXMLElement *)noteWithPitch:(int)pitch duration:(int)units useSharps:(BOOL)useSharps tied:(int)tied
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
				step= step=='A' ? 'G' : step-1; // Db -> C#
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
	if (tied & VLNote::kTiedWithPrev) {
		NSXMLElement * tie = [NSXMLNode elementWithName:@"tie"];
		[tie addAttribute: [NSXMLNode attributeWithName:@"type"
									  stringValue:@"stop"]];
		[note addChild:tie];
	}
	if (tied & VLNote::kTiedWithNext) {
		NSXMLElement * tie = [NSXMLNode elementWithName:@"tie"];
		[tie addAttribute: [NSXMLNode attributeWithName:@"type"
									  stringValue:@"start"]];
		[note addChild:tie];
	}
	[note addChild: [NSXMLNode elementWithName:@"voice"
							   stringValue: @"1"]];

	return note;
}

- (NSXMLElement *)syllable:(const VLSyllable *)syllable inStanza:(int)stanza
{
	NSString * syll;
	switch (syllable->fKind) {
	default:
	case VLSyllable::kSingle:
		syll	= @"single";
		break;
	case VLSyllable::kBegin:
		syll	= @"begin";
		break;
	case VLSyllable::kEnd:
		syll	= @"end";
		break;
	case VLSyllable::kMiddle:
		syll	= @"middle";
		break;
	}
	
	NSString * text = [NSString stringWithUTF8String:syllable->fText.c_str()];
	NSXMLNode* num	= [NSXMLNode attributeWithName:@"number"
								 stringValue:[NSString stringWithFormat:@"%d",
													   stanza]];
	return [NSXMLNode 
			   elementWithName:@"lyric" 
			   children: [NSArray arrayWithObjects:
				  [NSXMLNode elementWithName:@"syllabic" stringValue:syll],
				  [NSXMLNode elementWithName:@"text" stringValue:text],
				  nil]
			   attributes: [NSArray arrayWithObject:num]];
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
		NSXMLElement*n		= 
			[self noteWithPitch:note->fPitch duration:units useSharps:useSharps
				  tied:note->fTied];
		for (size_t i=0; i<note->fLyrics.size(); ++i)
			if (note->fLyrics[i])
				[n addChild:[self syllable:&note->fLyrics[i] inStanza:i+1]];

		[meas addChild:n];
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
			[meas addChild:[self noteWithPitch:chord->fPitch duration:units useSharps:useSharps tied:0]];
			continue;
		}
		if (chord->fRootPitch != VLNote::kNoPitch) {
			[meas addChild:[self noteWithPitch:chord->fRootPitch
								 duration:units useSharps:useSharps tied:0]];
			ch = [NSXMLNode elementWithName:@"chord"];
		}
		for (int step=0; step<32; ++step)
			if ((1 << step) > chord->fSteps) {
				break;
			} else if (chord->fSteps & (1 << step)) {
				NSXMLElement * note = 
					[self noteWithPitch:chord->fPitch+step
						  duration:units useSharps:useSharps tied:0];
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

- (NSXMLElement *) soundElt:(NSString *)title
{
	NSXMLElement * sound = [NSXMLNode elementWithName:@"sound"];
	[sound addAttribute: [NSXMLNode attributeWithName:title
									stringValue:@"A"]];
	return sound;
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

	size_t endMeasure = song->CountMeasures()-song->EmptyEnding();
	for (int measure = 0; measure < endMeasure; ++measure) {
		NSXMLElement * melMeas = [NSXMLNode elementWithName:@"measure"];
		[melMeas addAttribute: 
					 [NSXMLNode attributeWithName:@"number"
								stringValue:[NSString stringWithFormat:@"%d",
													  measure+1]]];
		if (!measure)
			[melMeas addChild:
						 [self attributesWithProps:song->fProperties.front()]];

		NSXMLElement * harMeas = [melMeas copy];
		
		size_t	volta;
		bool	repeat;
		int		times;
		if (song->DoesBeginRepeat(measure)) {
			NSXMLElement * barline = [NSXMLNode elementWithName:@"barline"];
			[barline addAttribute: [NSXMLNode attributeWithName:@"location"
											  stringValue:@"left"]];
			NSString * style = @"heavy-light";
			if (song->DoesEndRepeat(measure) 
			 || (song->DoesEndEnding(measure, &repeat) && repeat)
			)
				style = @"heavy-heavy";
			[barline addChild: [NSXMLNode elementWithName:@"bar-style"
										  stringValue:style]];
		    NSXMLElement * repeat = [NSXMLNode elementWithName:@"repeat"];
			[repeat addAttribute: [NSXMLNode attributeWithName:@"direction"
											 stringValue:@"forward"]];
			[barline addChild:repeat];
			[melMeas addChild:barline];
		} 
		if (song->DoesBeginEnding(measure, 0, &volta)) {
			NSXMLElement * barline = [NSXMLNode elementWithName:@"barline"];
			[barline addAttribute: [NSXMLNode attributeWithName:@"location"
											  stringValue:@"left"]];
		    NSXMLElement * ending = [NSXMLNode elementWithName:@"ending"];
			[ending addAttribute: [NSXMLNode attributeWithName:@"type"
											 stringValue:@"start"]];
			NSString * number = nil;
			for (size_t i = 0; i<8; ++i)
				if (volta & (1<<i))
					if (number)
						number = [NSString stringWithFormat:@"%@,%d", 
										   number, i+1];
					else
						number = [NSString stringWithFormat:@"%d", i+1];
			[ending addAttribute: [NSXMLNode attributeWithName:@"number"
											 stringValue:number]];
			[barline addChild:ending];
			[melMeas addChild:barline];
		}
		if (song->DoesEndRepeat(measure+1, &times)) {
			NSXMLElement * barline = [NSXMLNode elementWithName:@"barline"];
			[barline addAttribute: [NSXMLNode attributeWithName:@"location"
											  stringValue:@"right"]];
			NSString * style = @"light-heavy";
			if (song->DoesBeginRepeat(measure+1))
				style = @"heavy-heavy";
			[barline addChild: [NSXMLNode elementWithName:@"bar-style"
										  stringValue:style]];
		    NSXMLElement * repeat = [NSXMLNode elementWithName:@"repeat"];
			[repeat addAttribute: [NSXMLNode attributeWithName:@"direction"
											 stringValue:@"backward"]];
			[repeat addAttribute:
			  	[NSXMLNode attributeWithName:@"times"
						   stringValue:[NSString stringWithFormat:@"%d", times]]];
			[barline addChild:repeat];
			[melMeas addChild:barline];
		} 
		if (song->DoesEndEnding(measure+1, &repeat, &volta)) {
			NSXMLElement * barline = [NSXMLNode elementWithName:@"barline"];
			[barline addAttribute: [NSXMLNode attributeWithName:@"location"
											  stringValue:@"right"]];
			if (repeat) {
				NSString * style = @"light-heavy";
				if (song->DoesBeginRepeat(measure+1))
					style = @"heavy-heavy";
				[barline addChild: [NSXMLNode elementWithName:@"bar-style"
											  stringValue:style]];
				NSXMLElement * repeat = [NSXMLNode elementWithName:@"repeat"];
				[repeat addAttribute: [NSXMLNode attributeWithName:@"direction"
												 stringValue:@"backward"]];
				[barline addChild:repeat];
			}
		    NSXMLElement * ending = [NSXMLNode elementWithName:@"ending"];
			[ending addAttribute: 
				[NSXMLNode attributeWithName:@"type"
						   stringValue:repeat ? @"stop" : @"discontinue"]];
			NSString * number = nil;
			for (size_t i = 0; i<8; ++i)
				if (volta & (1<<i))
					if (number)
						number = [NSString stringWithFormat:@"%@,%d", 
										   number, i+1];
					else
						number = [NSString stringWithFormat:@"%d", i+1];
			[ending addAttribute: [NSXMLNode attributeWithName:@"number"
											 stringValue:number]];
			[barline addChild:ending];
			
			[melMeas addChild:barline];
		} 
		if (song->fCoda == measure)
			[melMeas addChild:[self soundElt:@"coda"]];

		[self addNotes:&song->fMeasures[measure].fMelody toMeasure:melMeas];
		[self addChords:&song->fMeasures[measure].fChords toMeasure:harMeas];

		if (song->fGoToCoda == measure+1) 
			[melMeas addChild:[self soundElt:@"tocoda"]];

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

- (NSArray *)propertyKeys
{
	static NSArray * sPropertyKeys = nil;
	
	if (!sPropertyKeys)
		sPropertyKeys = [[NSArray alloc] initWithObjects:
											 @"songGroove", @"songTempo", nil];

	return sPropertyKeys;
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
		NSDictionary * prop = 
			[self dictionaryWithValuesForKeys:[self propertyKeys]];
		[wrap addRegularFileWithContents:
				  [NSPropertyListSerialization dataFromPropertyList:prop
											   format:NSPropertyListXMLFormat_v1_0
											   errorDescription:nil]
			  preferredFilename:@"Properties"];
		if (vcsWrapper)
			[wrap addFileWrapper:vcsWrapper];

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

- (VLLyricsNote) readNote:(NSXMLElement*)note withUnit:(VLFraction)unit
{
	NSError *		outError;
	VLLyricsNote 	n;
	
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
	if ([note nodeForXPath:@".//tie[@type=\"stop\"]" error:&outError])
		n.fTied |= VLNote::kTiedWithPrev;
	NSEnumerator * e = [[note elementsForName:@"lyric"] objectEnumerator];
	for (NSXMLElement * lyric; lyric = [e nextObject]; ) {
		int stanza = [[[lyric attributeForName:@"number"]
						  stringValue] intValue];
		if (stanza > n.fLyrics.size())
			n.fLyrics.resize(stanza);
		--stanza;
		NSString * kind = [lyric stringForXPath:@"./syllabic" error:&outError];
		if ([kind isEqual:@"begin"])
			n.fLyrics[stanza].fKind	= VLSyllable::kBegin;
		else if ([kind isEqual:@"end"])
			n.fLyrics[stanza].fKind	= VLSyllable::kEnd;
		else if ([kind isEqual:@"middle"])
			n.fLyrics[stanza].fKind	= VLSyllable::kMiddle;
		else 
			n.fLyrics[stanza].fKind	= VLSyllable::kSingle;
		n.fLyrics[stanza].fText = 
			[[lyric stringForXPath:@"./text" error:&outError] UTF8String];
	}

	return n;
}

- (void) addRepeat:(VLRepeat *)repeat
{
	size_t end = repeat->fEndings.size() > 1 
		? repeat->fEndings[1].fBegin : repeat->fEndings[0].fEnd;
	song->AddRepeat(repeat->fEndings[0].fBegin, end, repeat->fTimes);
	for (size_t e = 1; e<repeat->fEndings.size(); ++e)
		song->AddEnding(repeat->fEndings[e].fBegin, repeat->fEndings[e].fEnd, 
						repeat->fEndings[e].fVolta);
}

- (void) readBarlines:(NSArray *)barlines measure:(int)m 
			   repeat:(VLRepeat *)repeat inRepeat:(bool *)inRepeat 
				error:(NSError **)outError
{
	NSEnumerator * e = [barlines objectEnumerator];
	for (NSXMLElement * barline; barline = [e nextObject]; ) {
		NSXMLElement * rep    = [barline nodeForXPath:@"./repeat" error:outError];
		NSXMLElement * ending = [barline nodeForXPath:@"./ending" error:outError];
		NSString * direction = nil;
		if (rep)
			direction = [rep stringForXPath:@"./@direction" error:outError];
		NSString * endingType = nil;
		size_t	   volta 	  = 0;
		int		   maxEnding  = 0;
		if (ending) {
			endingType 	= [ending stringForXPath:@"./@type" error:outError];
			NSEnumerator * n= 
				[[[ending stringForXPath:@"./@number" error:outError] 
					 componentsSeparatedByString:@","] objectEnumerator];
			for (NSString * num; num = [n nextObject]; ) {
				int n 		= [num intValue];
				maxEnding 	= n;
				volta	   |= 1<<(n-1);
			}
		}
			
		if ([direction isEqual:@"forward"]) {
			//
			// New repeat, add old one if there was one
			//
			if (*inRepeat)
				[self addRepeat:repeat];
			*inRepeat = true;
			repeat->fTimes	= 0;
			repeat->fEndings.clear();
			repeat->fEndings.push_back(VLRepeat::Ending(m, 0, 0));
		} else if ([endingType isEqual:@"start"]) {
			repeat->fTimes	= std::max<int8_t>(repeat->fTimes, maxEnding);
			repeat->fEndings.push_back(VLRepeat::Ending(m, 0, volta));
		} else if (endingType) {
			repeat->fEndings.back().fEnd	= m+1;
			repeat->fEndings[0].fEnd		= m+1;
		} else if (direction) {
			repeat->fTimes = [rep intForXPath:@"./@times" error:outError];
			repeat->fEndings[0].fEnd		= m+1;
		}
	}
}

- (void) readMelody:(NSArray *)measures error:(NSError **)outError
{
	NSEnumerator * e = [measures objectEnumerator];
	
	VLRepeat repeat;
	bool	 inRepeat = false;
	uint8_t	 prevKind[20];
	memset(prevKind, 0, 20);

	for (NSXMLElement * measure; measure = [e nextObject]; ) {
		VLProperties & 	prop = song->fProperties.front();
		VLFraction		unit(1, 4*prop.fDivisions);
		VLFraction		at(0);
		int				m = [[[measure attributeForName:@"number"]
								 stringValue] intValue]-1;

		[self readBarlines:[measure elementsForName:@"barline"] measure:m
			  repeat:&repeat inRepeat:&inRepeat error:outError];
		if ([measure nodeForXPath:@".//sound[@coda=\"A\"]" error:outError])
			song->fCoda = m;
		if ([measure nodeForXPath:@".//sound[@tocoda=\"A\"]" error:outError])
			song->fGoToCoda = m+1;
		NSEnumerator * n = [[measure elementsForName:@"note"] objectEnumerator];

		for (NSXMLElement * note; note = [n nextObject]; ) {
			VLLyricsNote n = [self readNote:note withUnit:unit];
			//
			// Sanitize syllabic information which was corrupt in early
			// versions.
			//
			for (size_t i = 0; i<n.fLyrics.size(); ++i)
				if (n.fLyrics[i].fText.size()) {
					if (!(prevKind[i] & VLSyllable::kHasNext))
						n.fLyrics[i].fKind &= ~VLSyllable::kHasPrev;
					prevKind[i] = n.fLyrics[i].fKind;
				}
			song->AddNote(n, m, at);
			at += n.fDuration;
		}
	}
	if (inRepeat)
		[self addRepeat:&repeat];
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
	song->clear();

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
	id groove   = [doc stringForXPath:@".//miscellaneous-field[@name=\"VocalEasel-groove\"]"
						error: outError];
	if (groove) {
		[songGroove autorelease];
		songGroove = [groove retain];
	}

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
	NSDictionary * wrappers = [wrapper fileWrappers];
	if ((vcsWrapper = [wrappers objectForKey:@"CVS"])
     || (vcsWrapper = [wrappers objectForKey:@".svn"])
	)
		[vcsWrapper retain];
	NSFileWrapper * prop = [wrappers objectForKey:@"Properties"];
	if (prop) {
		NSUndoManager * undoMgr = [self undoManager];
		[undoMgr disableUndoRegistration];
		[self setValuesForKeysWithDictionary:
				  [NSPropertyListSerialization 
					  propertyListFromData:[prop regularFileContents]
					  mutabilityOption:NSPropertyListImmutable
					  format:nil errorDescription:nil]];
		[undoMgr enableUndoRegistration];
	}
	return [self readFromXMLData:
					 [[wrappers objectForKey:@"Song"] regularFileContents]	
				 error:outError];
}

@end
