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

//
// To convert from and to complex file formats, we use ruby scripts operating
// on the XML representation of a Cocoa property list. The property list 
// representation is strictly intended as an intermediate representation, 
// subject to change as necessary.
//

@implementation VLDocument (Plist) 

class VLPlistVisitor : public VLSongVisitor {
public:
	VLPListVisitor(NSDictionary * plist, bool performanceOrder)
		: fPlist(plist), fPerfOrder(performanceOrder) {}

	virtual void Visit(VLSong & song);
protected:
	virtual void VisitMeasure(size_t m, VLProperties & p, VLMeasure & meas);
	virtual void VisitNote(VLLyricsNote & n);
	virtual void VisitChord(VLChord & c);

	NSDictionary *	fPlist;
	NSMutableArray *fMeasures;
	NSMutableArray *fNotes;
	NSMutableArray *fChords;
	bool			fPerfOrder;
	const VLSong *	fSong;
};

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
		[NSDictionary dictionaryWithValuesAndKeys:
		 [NSNumber numberWithInt:m], @"measure",
		 [NSNumber numberWithInt:meas.fPropIdx], @"properties",
		 fNotes, @"melody",
		 fChords, @"chords"];
	[fMeasures addObject:md];
}

void VLPlistVisitor::VisitNote(VLLyricsNote & n)
{
	NSDictionary * nd =
		[NSDictionary dictionaryWithValuesAndKeys:
		 [NSNumber numberWithInt:n.fDuration.fNum], @"durNum",
		 [NSNumber numberWithInt:n.fDuration.fDenom], @"durDenom",
		 [NSNumber numberWithInt:n.fPitch], @"pitch",
		 [NSNumber numberWithInt:n.fTied], @"tied",
		 [NSNumber numberWithInt:n.fVisual], @"visual"];
	[fNotes addObject:nd];
}

void VLPlistVisitor::VisitChord(VLChord & c)
{
	NSDictionary * cd = 
		[NSDictionary dictionaryWithValuesAndKeys:
		 [NSNumber numberWithInt:n.fDuration.fNum], @"durNum",
		 [NSNumber numberWithInt:n.fDuration.fDenom], @"durDenom",
		 [NSNumber numberWithInt:n.fPitch], @"pitch",
		 [NSNumber numberWithInt:n.fSteps], @"steps",
		 [NSNumber numberWithInt:n.fRootPitch], @"root"];
	[fChords addObject: cd];
}

- (id)plistInPerformanceOrder:(BOOL)performanceOrder
{
	NSMutableDictionary *	plist = 
		[NSMutableDictionary dictionaryWithCapacity:20];
	[plist setObject:songComposer forKey:@"composer"];
	[plist setObject:songLyricist forKey:@"lyricist"];
	[plist setObject:
			   [[NSDate date] 
				   descriptionWithCalendarFormat:@"%Y-%m-%d"
				   timeZone:nil locale:nil]
		   forKey:@"saved"];
	[plist setObject:
			   [NSString stringWithFormat:@"VocalEasel %@",
						 [[NSBundle mainBundle] 
							 objectForInfoDictionaryKey:@"CFBundleVersion"]]
		   forKey:@"software"];

	VLPlistVisitor	songWriter(plist, performanceOrder);
	songWriter.Visit(*song);

	return plist;
}

- (BOOL)readFromPlist:(id)plist error:(NSError **)outError
{
}

(NSData *)runFilter:(NSString *)filterName withContents:(NSData *)contents
{
}

- (NSFileWrapper *)fileWrapperWithFilter:(NSString *)filterName
								   error:(NSError **)outError
{
	NSBundle * 	mainBundle = [NSBundle mainBundle];
	BOOL 	 	perfOrder  = [mainBundle pathForResource:filterName	
							  ofType:@"pwriter" inDirectory:@"Filters"];
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
}

@end
