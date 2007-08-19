//
// File: VLPListDocument.h - Convert document from and to Cocoa plist
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2007 Matthias Neeracher
//

#import "VLPListDocument.h"
#import "VLModel.h"

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
	NSArray *		EncodeRepeats(const std::vector<VLRepeat> & repeats);
	NSDictionary *	EncodeRepeat(const VLRepeat & repeat);

	NSMutableDictionary *	fPlist;
	NSMutableArray *		fMeasures;
	NSMutableArray *		fNotes;
	NSMutableArray *		fChords;
	bool					fPerfOrder;
	const VLSong *			fSong;
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
			nil];
}

NSArray * VLPlistVisitor::EncodeRepeats(const std::vector<VLRepeat> & repeats)
{
	NSMutableArray * ra = [NSMutableArray arrayWithCapacity:repeats.size()];

	for (std::vector<VLRepeat>::const_iterator i = repeats.begin();
		 i != repeats.end(); ++i)
		[ra addObject:EncodeRepeat(*i)];

	return ra;
}

NSDictionary * VLPlistVisitor::EncodeRepeat(const VLRepeat & repeat)
{
	NSMutableArray * ea = [NSMutableArray arrayWithCapacity:repeat.fEndings.size()];

	for (std::vector<VLRepeat::Ending>::const_iterator i = repeat.fEndings.begin();
		 i != repeat.fEndings.end(); ++i)
		[ea addObject:[NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithInt: i->fBegin], @"begin",
			[NSNumber numberWithInt: i->fEnd], @"end",
			[NSNumber numberWithInt: i->fVolta], @"volta",
			nil]];
	
	return [NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithInt: repeat.fTimes], @"times",
			ea, @"endings",	
			nil];			 
}

void VLPlistVisitor::Visit(VLSong & song)
{
	fSong = &song;
	fMeasures = [NSMutableArray arrayWithCapacity:32];
	VisitMeasures(song, fPerfOrder);

	[fPlist setObject:EncodeProperties(song.fProperties) forKey:@"properties"];
	[fPlist setObject:EncodeRepeats(song.fRepeats) forKey:@"repeats"];
	[fPlist setObject:fMeasures forKey:@"measures"];
}

void VLPlistVisitor::VisitMeasure(size_t m, VLProperties & p, VLMeasure & meas)
{
	fNotes = [NSMutableArray arrayWithCapacity:1];
	fChords= [NSMutableArray arrayWithCapacity:1];
	
	VisitNotes(meas, p, true);
	VisitChords(meas);

	NSDictionary * md = 
		[NSDictionary dictionaryWithObjectsAndKeys:
		 [NSNumber numberWithInt:m], @"measure",
		 [NSNumber numberWithInt:meas.fPropIdx], @"properties",
		 fNotes, @"melody", fChords, @"chords",
		 nil];
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
		  
	NSDictionary * nd =
		[NSDictionary dictionaryWithObjectsAndKeys:
		 [NSNumber numberWithInt:n.fDuration.fNum], @"durNum",
		 [NSNumber numberWithInt:n.fDuration.fDenom], @"durDenom",
		 [NSNumber numberWithInt:n.fPitch], @"pitch",
		 [NSNumber numberWithInt:n.fTied], @"tied",
		 [NSNumber numberWithInt:n.fVisual], @"visual",
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
		 [NSNumber numberWithInt:c.fSteps], @"steps",
		 [NSNumber numberWithInt:c.fRootPitch], @"root",
		 nil];
	[fChords addObject: cd];
}

- (id)plistInPerformanceOrder:(BOOL)performanceOrder
{
	NSMutableDictionary *	plist = 
		[NSMutableDictionary dictionaryWithCapacity:20];
	[plist setObject:songTitle forKey:@"title"];
	[plist setObject:songGroove forKey:@"groove"];
	[plist setObject:songTempo forKey:@"tempo"];
	[plist setObject:songComposer forKey:@"composer"];
	[plist setObject:songLyricist forKey:@"lyricist"];
	[plist setObject:[NSDate date] forKey:@"saved"];
	[plist setObject:
			   [NSString stringWithFormat:@"VocalEasel %@",
						 [[NSBundle mainBundle] 
							 objectForInfoDictionaryKey:@"CFBundleVersion"]]
		   forKey:@"software"];

	VLPlistVisitor	songWriter(plist, performanceOrder);
	songWriter.Visit(*song);

	return plist;
}

- (IBAction)dump:(id)sender
{	
	id plist = [self plistInPerformanceOrder:NO];
	if ([sender tag]) 
		plist = [[[NSString alloc] initWithData:
			[NSPropertyListSerialization dataFromPropertyList:plist format:NSPropertyListXMLFormat_v1_0 errorDescription:nil]
				encoding:NSUTF8StringEncoding] autorelease];
	NSLog(@"%@\n", plist);
}

- (BOOL)readFromPlist:(id)plist error:(NSError **)outError
{
	return NO;
}

- (NSData *)runFilter:(NSString *)filterName withContents:(NSData *)contents
{
	return nil;
}

- (NSFileWrapper *)fileWrapperWithFilter:(NSString *)filterName
								   error:(NSError **)outError
{
	NSBundle * 	mainBundle = [NSBundle mainBundle];
	BOOL 	 	perfOrder  = [mainBundle pathForResource:filterName	
							  ofType:@"pwriter" inDirectory:@"Filters"] != nil;
	filterName = [filterName stringByAppendingPathExtension:
				  perfOrder ? @"pwriter" : @"writer"];
	NSData * inData = [self plistInPerformanceOrder:perfOrder];
	NSData * outData= [self runFilter:filterName withContents:inData];
	
	return [[[NSFileWrapper alloc] initRegularFileWithContents:outData]
			autorelease];
}

- (BOOL)readFromFileWrapper:(NSFileWrapper *)wrapper
				 withFilter:(NSString *)filterName
					  error:(NSError **)outError
{
	return NO;
}

@end
