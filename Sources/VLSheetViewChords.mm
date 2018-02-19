//
// File: VLSheetViewChords.mm - Chord editing functionality
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2006-2018 Matthias Neeracher
//

#import "VLSheetView.h"
#import "VLSheetViewChords.h"
#import "VLSheetViewInternal.h"
#import "VLDocument.h"

#import "VLModel.h"
#import "VLSoundOut.h"

std::string NormalizeName(NSString* rawName)
{
	std::string chordName =
		rawName ? (const char *)[[rawName lowercaseString] UTF8String] : "";
	//
	// Normalize # and b
	//
	for (;;) {
		size_t found;

		found = chordName.find(" ", 0, 1);
		if (found != std::string::npos) {
			chordName.erase(found);
			continue;
		} 		
		break;
	}

	return chordName;
}

@interface NSAttributedString (Chords) 

+ (NSAttributedString *) attributedStringWithCppString:(const std::string &)s
											attributes:(NSDictionary *)a;

@end

@implementation NSAttributedString (Chords)

+ (NSAttributedString *) attributedStringWithCppString:(const std::string &)s
											attributes:(NSDictionary *)a
{
	return [[[NSAttributedString alloc]
				initWithString:[NSString stringWithUTF8String:s.c_str()]
				attributes: a]
			   autorelease];
}

@end

@implementation VLChordEditable

- (VLChordEditable *)initWithView:(VLSheetView *)view
							 song:(VLSong *)song 
							   at:(VLLocation)at;
{
	self        = [super init];
	fView       = view;
	fSong       = song;
    fSelection  = at;
	
	[fView setNeedsDisplay: YES];
	
	return self;
}

- (NSString *) stringValue
{
	if (fSelection.fMeasure >= fSong->CountMeasures())
		return @"";

	const VLMeasure		measure = fSong->fMeasures[fSelection.fMeasure];
	const VLChordList &	chords	= measure.fChords;
	VLFraction at(0);
	for (VLChordList::const_iterator chord = chords.begin();
		 chord != chords.end() && at <= fSelection.fAt;
		 ++chord
	) {
		if (at == fSelection.fAt && chord->fPitch != VLNote::kNoPitch) {
			//
			// Found it!
			//
			VLSoundOut::Instance()->PlayChord(*chord);

			const VLProperties & 	prop	= fSong->Properties(fSelection.fMeasure);
			std::string name, ext, root;
			chord->Name(name, ext, root, prop.fKey > 0);
			
			NSString * ns = [NSString stringWithUTF8String:name.c_str()];
			NSString * es = [NSString stringWithUTF8String:ext.c_str()];
			NSString * rs = [NSString stringWithUTF8String:root.c_str()];

			return [NSString stringWithFormat:@"%@%@%s%@", ns, es, 
							 [rs length] ? "/" : "", rs];
		}
		at += chord->fDuration;
	}
	return @"";
}

- (void) setStringValue:(NSString *)val
{
	std::string	chordName	= NormalizeName(val);
	if (!chordName.size()) {
		[[fView document] willChangeSong];
		fSong->DelChord(fSelection);
		[[fView document] didChangeSong];
	} else {
		VLChord 	chord(chordName);
		VLSoundOut::Instance()->PlayChord(chord);
		
		[[fView document] willChangeSong];
		fSong->AddChord(chord, fSelection);
		[[fView document] didChangeSong];
	}
}

- (BOOL) validValue:(NSString *)val
{
	std::string	chordName	= NormalizeName(val);
	if (!chordName.size())
		return YES;

	//
	// Check for valid chord
	//
	VLChord 	chord(chordName);
	
	return chord.fPitch != VLNote::kNoPitch;
}

- (void) moveToNext
{	
	const VLProperties & prop = fSong->Properties(fSelection.fMeasure);

	fSelection.fAt = fSelection.fAt+VLFraction(1,4);
	if (fSelection.fAt >= prop.fTime) {
		fSelection.fAt 		= VLFraction(0,4);
		fSelection.fMeasure = (fSelection.fMeasure+1) % fSong->CountMeasures();
		[fView scrollMeasureToVisible:fSelection.fMeasure];
	}
}

- (void) moveToPrev
{
	if (fSelection.fAt < VLFraction(1,4)) {
        fSelection.fMeasure         =
            (fSelection.fMeasure+fSong->CountMeasures()-1) % fSong->CountMeasures();
		const VLProperties & prop   = fSong->Properties(fSelection.fMeasure);
		fSelection.fAt              = prop.fTime - VLFraction(1,4);
		[fView scrollMeasureToVisible:fSelection.fMeasure];
	} else
		fSelection.fAt = fSelection.fAt-VLFraction(1,4);
}

- (void) highlightCursor
{
	[fView highlightChord:fSelection];
}

@end

@implementation VLSheetView (Chords)

- (NSAttributedString *) stringWithChord:(const VLChord &)chord
{
	const VLSong *			song 		= [self song];
	const VLProperties & 	prop		= song->fProperties.front();

	static NSDictionary * sBigFont 	 = nil;
	static NSDictionary * sSuperFont = nil;
	if (!sBigFont)
		sBigFont =
			[[NSDictionary alloc] initWithObjectsAndKeys:
				[NSFont fontWithName: @"Helvetica" size: 14],
                NSFontAttributeName,
				nil];
	if (!sSuperFont)
		sSuperFont =
			[[NSDictionary alloc] initWithObjectsAndKeys:
				[NSFont fontWithName: @"Helvetica" size: 12],
				NSFontAttributeName,
				[NSNumber numberWithInt: 1],
                NSSuperscriptAttributeName,
				nil];

	std::string name, ext, root;
	if (chord.fPitch != VLNote::kNoPitch)
		chord.Name(name, ext, root, prop.fKey > 0);
	
	NSMutableAttributedString * s =
		[[[NSMutableAttributedString alloc] init] autorelease];
	[s appendAttributedString: 
		   [NSAttributedString attributedStringWithCppString: name
				 attributes: sBigFont]];
	[s appendAttributedString:
		   [NSAttributedString attributedStringWithCppString: ext.size() ? ext : " "
				 attributes: sSuperFont]];
	if (root.size())
		[s appendAttributedString:
			   [NSAttributedString attributedStringWithCppString: "/" + root
					 attributes: sBigFont]];

	return s;
}

- (void) drawChordsForSystem:(int)system
{
	const VLSong * 			song 		= [self song];
	const float 			kSystemY	= [self systemY:system];
	const int				kFirstMeas	= fLayout->FirstMeasure(system);
	const VLSystemLayout &	kLayout		= (*fLayout)[system];
	
	//
	// Build new list
	//
	for (int m = 0; m<kLayout.NumMeasures(); ++m) {
		uint32_t	measIdx = m+kFirstMeas;
		if (measIdx >= song->CountMeasures())
			break;
		const VLMeasure		measure = song->fMeasures[measIdx];
		const VLChordList &	chords	= measure.fChords;
		VLLocation at   = {measIdx, VLFraction(0)};
		for (VLChordList::const_iterator chord = chords.begin();
			 chord != chords.end();
			 ++chord
		) {
			NSAttributedString * chordName 	= [self stringWithChord:*chord];
			NSPoint				 chordLoc  	=
				NSMakePoint([self noteXAt:at], kSystemY+kChordY);
			[chordName drawAtPoint:chordLoc];
			at.fAt = at.fAt+chord->fDuration;
		}
	}
}

- (void) editChord
{
	VLEditable * e	= 
		[[VLChordEditable alloc]
			initWithView:self
			song:[self song]
			at:fCursorLocation];
	[self setEditTarget:e];
	[fFieldEditor selectText:self];
}

- (void) highlightChord:(VLLocation)at
{
	const VLProperties & 	prop = [self song]->Properties(at.fMeasure);
	const float 	   	kSystemY = [self systemY:fLayout->SystemForMeasure(at.fMeasure)];
	NSRect 				r 	   	 =
		NSMakeRect([self noteXAt:at]-kNoteW*0.5f,
				   kSystemY+kChordY, prop.fDivisions*kNoteW, kChordH);
	[[NSColor colorWithCalibratedWhite:0.8f alpha:1.0f] setFill];
	NSRectFillUsingOperation(r, NSCompositePlusDarker);
}

@end
