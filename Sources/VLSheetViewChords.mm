//
//  VLSheetViewChords.mm
//  Vocalese
//
//  Created by Matthias Neeracher on 1/4/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "VLSheetView.h"
#import "VLSheetViewChords.h"
#import "VLSheetViewInternal.h"

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

		found = chordName.find(kVLSharpStr, 0, 3);
		if (found != std::string::npos) {
			chordName.replace(found, 3, 1, '#');
			continue;
		}
		found = chordName.find(kVLFlatStr, 0, 3);
		if (found != std::string::npos) {
			chordName.replace(found, 3, 1, 'b');
			continue;
		} 
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
						  measure:(int)measure
							   at:(VLFract)at;
{
	self 	= [super init];
	fView	= view;
	fSong	= song;
	fMeasure= measure;
	fAt		= at;
	
	[fView setNeedsDisplay: YES];
	
	return self;
}

- (NSString *) stringValue
{
	const VLMeasure		measure = fSong->fMeasures[fMeasure];
	const VLChordList &	chords	= measure.fChords;
	VLFraction at(0);
	for (VLChordList::const_iterator chord = chords.begin();
		 chord != chords.end() && at <= fAt;
		 ++chord
	) {
		if (at == fAt && chord->fPitch != VLNote::kNoPitch) {
			//
			// Found it!
			//
			VLSoundOut::Instance()->PlayChord(*chord);

			const VLProperties & 	prop	= fSong->fProperties.front();
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
		fSong->DelChord(fMeasure, fAt);
	} else {
		VLChord 	chord(chordName);
		VLSoundOut::Instance()->PlayChord(chord);
		fSong->AddChord(chord, fMeasure, fAt);
		[fView setNeedsDisplay:YES];
	}
	[[fView document] updateChangeCount:NSChangeDone];
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
	const VLProperties & prop = fSong->fProperties.front();

	fAt = fAt+VLFraction(1,4);
	if (fAt >= prop.fTime) {
		fAt 		= VLFraction(0,4);
		fMeasure 	= (fMeasure+1) % fSong->CountMeasures();
		[fView scrollMeasureToVisible:fMeasure];
	}
}

- (void) moveToPrev
{
	if (fAt < VLFraction(1,4)) {
		const VLProperties & prop = fSong->fProperties.front();
		fAt 		= prop.fTime - VLFraction(1,4);
		fMeasure  	= 
			(fMeasure+fSong->CountMeasures()-1) % fSong->CountMeasures();
		[fView scrollMeasureToVisible:fMeasure];
	} else
		fAt = fAt-VLFraction(1,4);
}

- (void) highlightCursor
{
	[fView highlightChordInMeasure:fMeasure at:fAt];
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
	const VLSong * 	song 		= [self song];
	const float 	kSystemY	= [self systemY:system];
	
	//
	// Build new list
	//
	for (int m = 0; m<fMeasPerSystem; ++m) {
		int	measIdx = m+system*fMeasPerSystem;
		if (measIdx >= song->CountMeasures())
			break;
		const VLMeasure		measure = song->fMeasures[measIdx];
		const VLChordList &	chords	= measure.fChords;
		VLFraction at(0);
		for (VLChordList::const_iterator chord = chords.begin();
			 chord != chords.end();
			 ++chord
		) {
			NSAttributedString * chordName 	= [self stringWithChord:*chord];
			NSPoint				 chordLoc  	=
				NSMakePoint(fClefKeyW+(m+at)*fMeasureW+0.5f*kNoteW, 
							kSystemY+kChordY);
			[chordName drawAtPoint:chordLoc];
			at += chord->fDuration;
		}
	}
}

- (void) editChord
{
	VLEditable * e	= 
		[[VLChordEditable alloc]
			initWithView:self
			song:[self song]
			measure:fCursorMeasure
			at:fCursorAt];
	[self setEditTarget:e];
	[fFieldEditor selectText:self];
}

- (void) highlightChordInMeasure:(int)measure at:(VLFraction)at
{
	const VLProperties & 	prop = [self song]->fProperties.front();
	const float 	   	kSystemY = [self systemY:measure / fMeasPerSystem];
	NSRect 				r 	   	 =
		NSMakeRect([self noteXInMeasure:measure at:at]-kNoteW*0.5f,
				   kSystemY+kChordY, prop.fDivisions*kNoteW, kChordH);
	[[NSColor colorWithCalibratedWhite:0.8f alpha:1.0f] setFill];
	NSRectFillUsingOperation(r, NSCompositePlusDarker);
}

@end
