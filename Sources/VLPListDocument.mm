//
// File: VLPListDocument.h - Convert document from and to Cocoa plist
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2007-2011 Matthias Neeracher
//

#import "VLPListDocument.h"
#import "VLModel.h"
#import "VLPitchGrid.h"

//
// To convert from and to complex file formats, we use ruby scripts operating
// on the XML representation of a Cocoa property list. The property list 
// representation is strictly intended as an intermediate representation, 
// subject to change as necessary.
//

@implementation VLDocument (Plist) 

class VLPlistVisitor : public VLSongVisitor {
public:
	VLPlistVisitor(NSMutableDictionary * plist, bool performanceOrder)
		: fPlist(plist), fPerfOrder(performanceOrder) {}

	virtual void Visit(VLSong & song);
protected:
	virtual void VisitMeasure(size_t m, VLProperties & p, VLMeasure & meas);
	virtual void VisitNote(VLLyricsNote & n);
	virtual void VisitChord(VLChord & c);
	
	NSArray *		EncodeProperties(const std::vector<VLProperties> & properties);
	NSDictionary *	EncodeProperties(const VLProperties & properties);

	NSMutableDictionary *	fPlist;
	NSMutableArray *		fMeasures;
	NSMutableArray *		fNotes;
	NSMutableArray *		fChords;
	bool					fPerfOrder;
	const VLSong *			fSong;
    VLVisualFilter          fVisFilter;
};

NSArray * VLPlistVisitor::EncodeProperties(const std::vector<VLProperties> & properties)
{
	NSMutableArray * pa = [NSMutableArray arrayWithCapacity:properties.size()];

	for (std::vector<VLProperties>::const_iterator i = properties.begin();
		 i != properties.end(); ++i)
		[pa addObject:EncodeProperties(*i)];

	return pa;
}

NSDictionary * VLPlistVisitor::EncodeProperties(const VLProperties & properties)
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithInt: properties.fTime.fNum], @"timeNum",	 
			[NSNumber numberWithInt: properties.fTime.fDenom], @"timeDenom",
			[NSNumber numberWithInt: properties.fKey], @"key",
			[NSNumber numberWithInt: properties.fMode], @"mode",
			[NSNumber numberWithInt: properties.fDivisions], @"divisions",
			[NSString stringWithUTF8String:properties.fGroove.c_str()], @"groove",			 
			nil];
}

void VLPlistVisitor::Visit(VLSong & song)
{
	fSong = &song;
	fMeasures = [NSMutableArray arrayWithCapacity:32];
	VisitMeasures(song, fPerfOrder);

	[fPlist setObject:EncodeProperties(song.fProperties) forKey:@"properties"];
	[fPlist setObject:fMeasures forKey:@"measures"];
}

void VLPlistVisitor::VisitMeasure(size_t m, VLProperties & p, VLMeasure & meas)
{
	fNotes = [NSMutableArray arrayWithCapacity:1];
	fChords= [NSMutableArray arrayWithCapacity:1];
    
    fVisFilter.ResetWithKey(p.fKey);
	VisitNotes(meas, p, true);
	VisitChords(meas);

	NSMutableDictionary * md = 
		[NSMutableDictionary dictionaryWithObjectsAndKeys:
		 [NSNumber numberWithInt:m], @"measure",
		 [NSNumber numberWithInt:meas.fPropIdx], @"properties",
		 fNotes, @"melody", fChords, @"chords",
		 nil];
	int		times;
	bool 	last;
	size_t	volta;
	if (fSong->DoesBeginRepeat(m, &times)) 
		[md setObject:
		       [NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:times], @"times", nil]
			forKey: @"begin-repeat"];
	if (fSong->DoesBeginEnding(m, &last, &volta)) 
		[md setObject:
		       [NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithBool:!last], @"last",
				[NSNumber numberWithInt:volta], @"volta",
				nil]
			forKey: @"begin-ending"];
	if (fSong->DoesEndRepeat(m+1, &times)) 
		[md setObject:
		       [NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:times], @"times", nil]
			forKey: @"end-repeat"];
	if (fSong->DoesEndEnding(m+1, &last, &volta)) 
		[md setObject:
		       [NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithBool:!last], @"last",
				[NSNumber numberWithInt:volta], @"volta",
				nil]
			forKey: @"end-ending"];
	if (fSong->fGoToCoda == m+1)
		[md setObject:[NSNumber numberWithBool:YES] forKey:@"tocoda"];
	if (fSong->fCoda == m)
		[md setObject:[NSNumber numberWithBool:YES] forKey:@"coda"];
	if (meas.fBreak & VLMeasure::kNewSystem)
		[md setObject:[NSNumber numberWithBool:YES] forKey:@"new-system"];
	if (meas.fBreak & VLMeasure::kNewPage)
		[md setObject:[NSNumber numberWithBool:YES] forKey:@"new-page"];
	[fMeasures addObject:md];
}

void VLPlistVisitor::VisitNote(VLLyricsNote & n)
{
	NSMutableArray * ly = [NSMutableArray arrayWithCapacity:0];
	for (size_t i = 0; i<n.fLyrics.size(); ++i)
		[ly addObject:n.fLyrics[i].fText.size() 
		  ? [NSDictionary dictionaryWithObjectsAndKeys:
			 [NSString stringWithUTF8String:n.fLyrics[i].fText.c_str()], @"text",
			 [NSNumber numberWithInt:n.fLyrics[i].fKind], @"kind",
			 nil]
		  : [NSDictionary dictionary]];
    
    int grid = VLPitchToGrid(n.fPitch, n.fVisual, 0);
	NSDictionary * nd =
		[NSDictionary dictionaryWithObjectsAndKeys:
		 [NSNumber numberWithInt:n.fDuration.fNum], @"durNum",
		 [NSNumber numberWithInt:n.fDuration.fDenom], @"durDenom",
		 [NSNumber numberWithInt:n.fPitch], @"pitch",
		 [NSNumber numberWithInt:n.fTied], @"tied",
		 [NSNumber numberWithInt:fVisFilter(grid, n.fVisual)], @"visual",
		 ly, @"lyrics",
		 nil];
	[fNotes addObject:nd];
}

void VLPlistVisitor::VisitChord(VLChord & c)
{
	NSDictionary * cd = 
		[NSDictionary dictionaryWithObjectsAndKeys:
		 [NSNumber numberWithInt:c.fDuration.fNum], @"durNum",
		 [NSNumber numberWithInt:c.fDuration.fDenom], @"durDenom",
		 [NSNumber numberWithInt:c.fPitch], @"pitch",
		 [NSNumber numberWithInt:c.fVisual], @"visual",
		 [NSNumber numberWithInt:c.fSteps], @"steps",
		 [NSNumber numberWithInt:c.fRootPitch], @"root",
		 nil];
	[fChords addObject: cd];
}

- (id)plistInPerformanceOrder:(BOOL)performanceOrder
{
	NSMutableDictionary *	plist = 
		[NSMutableDictionary dictionaryWithObjectsAndKeys:
		 songTitle, @"title", songTempo, @"tempo",
		 [NSString stringWithUTF8String:song->PrimaryGroove().c_str()], @"groove", 
		 songComposer, @"composer", songLyricist, @"lyricist",
		 [NSDate date], @"saved",
		 [NSString stringWithFormat:@"VocalEasel %@",
				   [[NSBundle mainBundle] 
					   objectForInfoDictionaryKey:@"CFBundleVersion"]],
		 @"software",
		 nil];

	VLPlistVisitor	songWriter(plist, performanceOrder);
	songWriter.Visit(*song);

	return plist;
}

- (IBAction)dump:(id)sender
{	
	id plist = [self plistInPerformanceOrder:NO];
	switch ([sender tag]) {
	case 0:
		//
		// Dump as plist
		//
		NSLog(@"\n%@\n", plist);
		break;
	case 1:
		//
		// Dump as XML
		//
		plist = [[[NSString alloc] initWithData:
					 [NSPropertyListSerialization dataFromPropertyList:plist 
												  format:NSPropertyListXMLFormat_v1_0 errorDescription:nil]
								   encoding:NSUTF8StringEncoding] autorelease];
		NSLog(@"\n%@\n", plist);
		break;	
	case 2:
		//
		// Dump after roundtrip
		//
		[self readFromPlist:plist error:nil];
		plist = [self plistInPerformanceOrder:NO];
		NSLog(@"\n%@\n", plist);
		break;
	}
}

//
// We try to keep the number of divisions as small as possible, so we keep track
// of all note onsets per quarter note. In addition, we keep track of potential
// swing 8ths [0, 1/8]->[0,1/6] and 
// swing 16ths [0,1/16]->[0,1/12] [1/8,3/16]->[1/8,1/6]
// so we can recognize swing songs containing triplets and note them with 3 (6)
// divisions instead of 6 (12)
//
enum {
	kPotentialSwing8th = 12,
	kPotentialSwing16th
};

- (void)readMelody:(NSArray *)melody inMeasure:(size_t)measNo onsets:(int *)onsets lyrics:(uint8_t *)prevKind
{
	VLFraction		at(0);
	int				lastOnset = 0;
	VLFraction		tiedStart(0);
	VLLyricsNote	tiedNote;

	for (NSEnumerator * ne 	  = [melody objectEnumerator];
		 NSDictionary * ndict = [ne nextObject];
	) {	
		VLLyricsNote note;
		note.fDuration = 
			VLFraction([[ndict objectForKey:@"durNum"] intValue],
					   [[ndict objectForKey:@"durDenom"] intValue],
					   true);
		note.fPitch	   = [[ndict objectForKey:@"pitch"] intValue];	
		note.fVisual  |= [[ndict objectForKey:@"visual"] intValue]
			& VLNote::kAccidentalsMask;
		note.fTied	   = 0;
		
		if ([[ndict objectForKey:@"tied"] intValue] & VLNote::kTiedWithPrev) {
			if (at != 0) {
				//
				// Extend preceding note
				//
				tiedNote.fDuration	+= note.fDuration;
				song->DelNote(measNo, tiedStart);
				song->AddNote(tiedNote, measNo, tiedStart);
				
				goto advanceAt;
			} else {
				//
				// Extend previous measure
				//
				note.fTied |= VLNote::kTiedWithPrev;
			}
		} else {
			for (NSEnumerator * le 	  = [[ndict objectForKey:@"lyrics"] objectEnumerator];
				 NSDictionary * ldict = [le nextObject];
			) {	
				VLSyllable syll;

				if (NSString * t = [ldict objectForKey:@"text"])
					syll.fText = [t UTF8String];

				syll.fKind = [[ldict objectForKey:@"kind"] intValue];

				note.fLyrics.push_back(syll);
			}
		}

		//
		// Sanitize syllabic information which was corrupt in early
		// versions.
		//
		for (size_t i = 0; i<note.fLyrics.size(); ++i)
			if (note.fLyrics[i].fText.size()) {
				if (!(prevKind[i] & VLSyllable::kHasNext))
					note.fLyrics[i].fKind &= ~VLSyllable::kHasPrev;
				prevKind[i] = note.fLyrics[i].fKind;
			}		

		tiedStart	= at;
		tiedNote	= note;
		
		song->AddNote(note, measNo, at);

		if (!(note.fTied & VLNote::kTiedWithPrev)) {
			VLFraction 	inQuarter	= at % VLFraction(1,4);
			int 		onset 		= inQuarter.fNum * 48 / inQuarter.fDenom;
			++onsets[onset];
			switch (onset) {
			case 3:
				if (lastOnset == 0)
					++onsets[kPotentialSwing16th];
				break;					
			case 6:
				if (lastOnset == 0)
					++onsets[kPotentialSwing8th];
				break;
			case 9:
				if (lastOnset == 6 || lastOnset == 3 || lastOnset == 0)
					++onsets[kPotentialSwing16th];
				break;
			}
		}
advanceAt:
		at += note.fDuration;		
	}
}

- (void)readChords:(NSArray *)chords inMeasure:(size_t)measNo
{
	VLFraction	at(0);

	for (NSEnumerator * ce 	  = [chords objectEnumerator];
		 NSDictionary * cdict = [ce nextObject];
	) {	
		VLChord chord;
		chord.fDuration = 
			VLFraction([[cdict objectForKey:@"durNum"] intValue],
					   [[cdict objectForKey:@"durDenom"] intValue],
					   true);
		chord.fPitch			= [[cdict objectForKey:@"pitch"] intValue];	
		chord.fRootPitch		= [[cdict objectForKey:@"root"] intValue];	
		chord.fSteps			= [[cdict objectForKey:@"steps"] intValue];	

		song->AddChord(chord, measNo, at);
		
		at += chord.fDuration;
	}
}

- (void)readMeasuresFromPlist:(NSArray *)measures
{
	std::vector<size_t>	repeatStack;

	size_t measNo = 0;
	int onsets[14] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
	uint8_t  		lyricsKind[20];
	memset(lyricsKind, 0, 20*sizeof(lyricsKind[0]));
	for (NSEnumerator * me 	  = [measures objectEnumerator];
		 NSDictionary * mdict = [me nextObject];
		 ++measNo
	) {
		if (NSNumber * mNo = [mdict objectForKey:@"measure"])
			measNo = static_cast<size_t>([mNo intValue]);
		if (NSNumber * mPx = [mdict objectForKey:@"properties"]) 
			song->SetProperties(measNo, [mPx intValue]);

		[self readMelody:[mdict objectForKey:@"melody"] inMeasure:measNo onsets:onsets lyrics:&lyricsKind[0]];
		[self readChords:[mdict objectForKey:@"chords"] inMeasure:measNo];

		if ([[mdict objectForKey:@"tocoda"] boolValue])
			song->fGoToCoda = measNo+1;
		if ([[mdict objectForKey:@"coda"] boolValue])
			song->fCoda = measNo;			
		if ([[mdict objectForKey:@"new-system"] boolValue])
			song->fMeasures[measNo].fBreak |= VLMeasure::kNewSystem;
		if ([[mdict objectForKey:@"new-page"] boolValue])
			song->fMeasures[measNo].fBreak |= VLMeasure::kNewPage;
		
		if (NSDictionary * beginRep = [mdict objectForKey:@"begin-repeat"]) {
			VLRepeat 			rep;
			VLRepeat::Ending	ending(measNo, measNo, 0);

			rep.fTimes	= [[beginRep objectForKey:@"times"] intValue];
			rep.fEndings.push_back(ending);

			repeatStack.push_back(song->fRepeats.size());
			song->fRepeats.push_back(rep);
		}
		if (NSDictionary * beginEnd = [mdict objectForKey:@"begin-ending"]) {
			VLRepeat & 			rep = song->fRepeats[repeatStack.back()];
			VLRepeat::Ending	ending(measNo, measNo, 0);

			ending.fVolta	= [[beginEnd objectForKey:@"volta"] intValue];
			rep.fEndings.push_back(ending);
		}
		if (NSDictionary * endEnd = [mdict objectForKey:@"end-ending"]) {
			VLRepeat & 			rep 	= song->fRepeats[repeatStack.back()];
			VLRepeat::Ending &	ending 	= rep.fEndings.back();

			ending.fEnd = measNo+1;
			if (NSNumber * volta = [endEnd objectForKey:@"volta"])
				ending.fVolta = [volta intValue];
			while ((((1<<rep.fTimes) - 1) & ending.fVolta) < ending.fVolta)
				++rep.fTimes;
			if ([[endEnd objectForKey:@"last"] boolValue]) {
				rep.fEndings[0].fEnd = measNo+1;
				repeatStack.pop_back();
			}
		}
		if (NSDictionary * endRep = [mdict objectForKey:@"end-repeat"]) {
			VLRepeat & 			rep = song->fRepeats[repeatStack.back()];

			if (NSNumber * times = [endRep objectForKey:@"times"])
				rep.fTimes = [times intValue];

			rep.fEndings[0].fEnd 	= measNo+1;
			rep.fEndings[0].fVolta	= (1<<rep.fTimes)-1;

			repeatStack.pop_back();
		}
	}
	size_t empty = song->EmptyEnding();
	while (empty-- > 1)
		song->fMeasures.pop_back();
	if (!song->fProperties.back().fDivisions) {
		if (!(onsets[1]+onsets[5]+onsets[7]+onsets[11]))
			if (!(onsets[3]+onsets[9]-onsets[kPotentialSwing16th]))
				if (onsets[kPotentialSwing16th]) {
					song->fProperties.back().fDivisions = 12;
					song->ChangeDivisions(song->fProperties.size()-1, 6);
				} else if (!(onsets[2]+onsets[4]+onsets[8]+onsets[10])) {
					song->fProperties.back().fDivisions = 2;
				} else if (!(onsets[2]+onsets[10]
						   + onsets[6]-onsets[kPotentialSwing8th])) {
					if (onsets[kPotentialSwing8th]) {
						song->fProperties.back().fDivisions = 6;
						song->ChangeDivisions(song->fProperties.size()-1, 3);
					} else {
						song->fProperties.back().fDivisions = 3;
					}
				} else {
					song->fProperties.back().fDivisions = 6;
		        }
			else if (!(onsets[2]+onsets[4]+onsets[8]+onsets[10]))
				song->fProperties.back().fDivisions = 4;
			else	
				song->fProperties.back().fDivisions = 12;
		else	
			song->fProperties.back().fDivisions = 12;
	}
}

- (void)readPropertiesFromPlist:(NSArray *)properties
{
	song->fProperties.clear();
	for (NSEnumerator * pe = [properties objectEnumerator];
		 NSDictionary * pdict = [pe nextObject];
	) {
		VLProperties prop;

		prop.fTime = 
			VLFraction([[pdict objectForKey:@"timeNum"] intValue],
					   [[pdict objectForKey:@"timeDenom"] intValue],
					   false);
		prop.fKey			= [[pdict objectForKey:@"key"] intValue];
		prop.fMode			= [[pdict objectForKey:@"mode"] intValue];
		prop.fDivisions		= [[pdict objectForKey:@"divisions"] intValue];

		if (NSString * groove = [pdict objectForKey:@"groove"])
			prop.fGroove	= [groove UTF8String];
		else
			prop.fGroove	= [songGroove UTF8String];

		song->fProperties.push_back(prop);
	}
}

- (void)setValueFromPlist:(id)plist plistKey:(NSString *)plistKey forKey:(NSString *)key
{
	id value = [plist objectForKey:plistKey];
	if (value)
		[self setValue:value forKey:key];
}

- (BOOL)readFromPlist:(id)plist error:(NSError **)outError
{
	NSUndoManager * undoMgr = [self undoManager];
	[undoMgr disableUndoRegistration];
	song->clear();

	[self setValueFromPlist:plist plistKey:@"title" forKey:@"songTitle"];
	[self setValueFromPlist:plist plistKey:@"composer" forKey:@"songComposer"];
	[self setValueFromPlist:plist plistKey:@"lyricist" forKey:@"songLyricist"];
	[self setValueFromPlist:plist plistKey:@"groove" forKey:@"songGroove"];
	[self setValueFromPlist:plist plistKey:@"tempo" forKey:@"songTempo"];
	[self readPropertiesFromPlist:[plist objectForKey:@"properties"]];
	[self readMeasuresFromPlist:[plist objectForKey:@"measures"]];
	[undoMgr enableUndoRegistration];
    
    if (song->fMeasures.empty()) {
        delete song;
        song = new VLSong(true);
    }

	return YES;
}

- (NSData *)runFilter:(NSString *)filterName withContents:(NSData *)contents
{
	NSString * filterPath = [[NSBundle mainBundle] pathForResource:filterName
												   ofType:nil
												   inDirectory:@"Filters"];
	NSPipe * filterInput  = [NSPipe pipe];
	NSPipe * filterOutput = [NSPipe pipe];
	NSPipe * filterError  = [NSPipe pipe];

	NSTask * filterTask	= [[NSTask alloc] init];
	[filterTask setLaunchPath:filterPath];
	[filterTask setStandardInput:filterInput];
	[filterTask setStandardOutput:filterOutput];
	[filterTask setStandardError:filterError];
	[filterTask launch];

	NSFileHandle * inputHandle = [filterInput fileHandleForWriting];
	[inputHandle writeData:contents];
	[inputHandle closeFile];

	NSFileHandle * outputHandle = [filterOutput fileHandleForReading];
	NSData * 	   output		= [outputHandle readDataToEndOfFile];
 	
	NSFileHandle * errorHandle  = [filterError fileHandleForReading];
	NSData * 	   error		= [errorHandle readDataToEndOfFile];
 	
	[filterTask waitUntilExit];
	[filterTask release];

	if ([error length]) {
		NSString * errStr = [[[NSString alloc] initWithData:error 
			encoding:NSUTF8StringEncoding] autorelease];
		[NSException raise:NSInvalidArgumentException 
					 format:@"Filter %@: %@", filterName, errStr];
	}
	
	return output;
}

- (NSFileWrapper *)fileWrapperWithFilter:(NSString *)filterName
								   error:(NSError **)outError
{
	NSBundle * 	mainBundle = [NSBundle mainBundle];
	BOOL 	 	perfOrder  = [mainBundle pathForResource:filterName	
							  ofType:@"pwriter" inDirectory:@"Filters"] != nil;
	filterName = [filterName stringByAppendingPathExtension:
				  perfOrder ? @"pwriter" : @"writer"];
	id 		 inPlist= [self plistInPerformanceOrder:perfOrder];
	NSData * inData = 
		[NSPropertyListSerialization dataFromPropertyList:inPlist
									 format:NSPropertyListXMLFormat_v1_0 
									 errorDescription:nil];
	NSData * outData= [self runFilter:filterName withContents:inData];
	
	return [[[NSFileWrapper alloc] initRegularFileWithContents:outData]
			autorelease];
}

- (BOOL)readFromFileWrapper:(NSFileWrapper *)wrapper
				 withFilter:(NSString *)filterName
					  error:(NSError **)outError
{
	filterName = [filterName stringByAppendingPathExtension:@"reader"];

	NSData * inData 	= [wrapper regularFileContents];
	NSData * outData	= [self runFilter:filterName withContents:inData];
	NSString*errString;
	id       outPlist	= 
		[NSPropertyListSerialization propertyListFromData:outData
									 mutabilityOption:NSPropertyListImmutable
									 format:NULL errorDescription:&errString];
	if (!outPlist) 
		[NSException raise:NSInvalidArgumentException 
					 format:@"Plist %@: %@", filterName, errString];
	return [self readFromPlist:outPlist error:outError];
}

@end 
