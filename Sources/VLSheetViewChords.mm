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

@implementation VLSheetView (Chords)

- (NSAttributedString *) attributedStringWithCppString:(const std::string &)s
											attributes:(NSDictionary *)a
{
	return [[[NSAttributedString alloc]
				initWithString:[NSString stringWithUTF8String:s.c_str()]
				attributes: a]
			   autorelease];
}

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
		   [self attributedStringWithCppString: name
				 attributes: sBigFont]];
	[s appendAttributedString:
		   [self attributedStringWithCppString: ext.size() ? ext : " "
				 attributes: sSuperFont]];
	if (root.size())
		[s appendAttributedString:
			   [self attributedStringWithCppString: "/" + root
					 attributes: sBigFont]];

	return s;
}

- (void) setupChords
{
	const VLSong *			song 		= [self song];
	const VLProperties & 	prop		= song->fProperties.front();
	NSView *				chordView	= [chords contentView];

	//	
	// Delete old list of chord boxes
	//
	for (NSEnumerator * e = [[chordView subviews] objectEnumerator];
		 NSView * subview = [e nextObject];
	) 
		[subview removeFromSuperview];
	
	//
	// Build new list
	//
	NSFont * chordFont   = [NSFont controlContentFontOfSize: 14];
	int beatsPerGroup = quarterBeats / groups;
	for (int m = 0; m<visibleMeasures; ++m) {
		const float x0 = clefKeyW+m*measureW;
		int measure = firstMeasure+m;
		VLChordList::const_iterator cCur = song->fMeasures[measure].fChords.begin();
		VLChordList::const_iterator cEnd = song->fMeasures[measure].fChords.end();
		VLFraction			  at(0);
		for (int beat = 0; beat<quarterBeats; ++beat) {
			const float x = x0+kNoteW*(beat*prop.fDivisions+(beat / beatsPerGroup)+0.5f);
			NSRect f = NSMakeRect(x, 0, kChordW, kChordH);
			NSButton * chord = [[NSButton alloc] initWithFrame: f];
			[chordView addSubview: chord];
			[chord setBordered: NO];
			[chord setTarget: self];
			[chord setAction: @selector(editChord:)];
			[chord setTag: (measure << 8) | beat];
			[chord setFont: chordFont];
			[chord setTitle: @""];
			while (cCur != cEnd && at < VLFraction(beat, 4)) 
				at += (cCur++)->fDuration;
			if (cCur != cEnd && at == VLFraction(beat, 4) && cCur->fPitch != VLNote::kNoPitch)
				[chord setTitle: [self stringWithChord:*cCur]];
			[chord release];
		}
	}
	[chords setNeedsDisplay: YES];
}

- (IBAction) editChord:(id)sender
{
	[self showFieldEditor:sender withAction:@selector(doneEditingChord:)];
}

- (IBAction) doneEditingChord:(id)sender
{
	VLSong * 				song = [self song];

	std::string chordName =
		(const char *)[[[sender stringValue] lowercaseString] UTF8String];
	//
	// Normalize # and b
	//
	for (;;) {
		size_t found;

		found = chordName.find("\xE2\x99\xAF", 0, 3);
		if (found != std::string::npos) {
			chordName.replace(found, 3, 1, '#');
			continue;
		}
		found = chordName.find("\xE2\x99\xAD", 0, 3);
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
	//
	// Check for valid chord
	//
	VLChord chord(chordName);
	if (!chordName.size()) {
		[sender setTextColor: [NSColor blackColor]];
	} else if (chord.fPitch == VLChord::kNoPitch) {
		if (chordName.size()) {
			NSBeep();
			[sender setTextColor: [NSColor redColor]];
		}
		int tag = [sender tag];
		song->DelChord(tag >> 8, VLFraction(tag & 0xFF, 4));
	} else {
		NSAttributedString * s =  [self stringWithChord:chord];
		[sender setAttributedStringValue: s];
		[fieldBeingEdited setTitle: s];
		[sender setTextColor: [NSColor blackColor]];
		VLSoundOut::Instance()->PlayChord(chord);
		int tag = [fieldBeingEdited tag];
		song->AddChord(chord, tag >> 8, VLFraction(tag & 0xFF, 4));
	}
}

@end
