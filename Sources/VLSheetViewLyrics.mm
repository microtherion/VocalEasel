//
// File: VLSheetViewLyrics.mm - Lyrics editing functionality
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2006-2007 Matthias Neeracher
//

#import "VLSheetView.h"
#import "VLSheetViewLyrics.h"
#import "VLSheetViewInternal.h"
#import "VLDocument.h"

#import "VLModel.h"
#import "VLSoundOut.h"

@implementation VLLyricsEditable

- (VLLyricsEditable *)initWithView:(VLSheetView *)view
							 song:(VLSong *)song 
							stanza:(int)stanza
						  measure:(int)measure
							   at:(VLFract)at
{
	self 		= [super init];
	fView		= view;
	fSong		= song;
	fStanza		= stanza;
	fMeasure	= measure;
	fAt 		= at;
	fNextMeas	= fMeasure;
	fNextAt		= fAt;
	
	VLFraction At = fAt;
	fSong->FindWord(fStanza, fMeasure, At);
	fAt = At;
	[fView highlightTextInStanza:fStanza measure:fMeasure at:fAt one:NO];

	[fView setNeedsDisplay: YES];
	
	return self;
}

- (NSString *) stringValue
{
	std::string word = fSong->GetWord(fStanza, fMeasure, fAt);
	return [NSString stringWithUTF8String:word.c_str()];
}

- (void) setStringValue:(NSString *)val
{
	[[fView document] willChangeSong];
	fSong->SetWord(fStanza, fMeasure, fAt, val ? [val UTF8String] : "", &fNextMeas, &fNextAt);
	[[fView document] didChangeSong];
}

- (BOOL) validValue:(NSString *)val
{
	return YES;
}

- (void) moveToNext
{
	if (fNextMeas != fMeasure || fNextAt != fAt) {
		fMeasure = fNextMeas;
		VLFraction at = fNextAt;
		fSong->FindWord(fStanza, fMeasure, at);
		fAt	 = at;
	} else {
		VLFraction at = fAt;
		if (!fSong->NextWord(fStanza, fMeasure, at)) {
			fMeasure	= 0;
			at			= 0;
			fSong->FindWord(fStanza, fMeasure, at);
		}
		fAt = at;
	}
	fNextMeas = fMeasure;
	fNextAt	  = fAt;
	[fView highlightTextInStanza:fStanza measure:fMeasure at:fAt];
	[fView scrollMeasureToVisible:fMeasure];
}

- (void) moveToPrev
{
	VLFraction at = fAt;
	if (!fSong->PrevWord(fStanza, fMeasure, at)) {
		fMeasure = fSong->CountMeasures()-1;
		at		 = fSong->Properties(fMeasure).fTime;
		fSong->PrevWord(fStanza, fMeasure, at);
	}
	fAt = at;
	fNextMeas = fMeasure;
	fNextAt	  = fAt;
	[fView highlightTextInStanza:fStanza measure:fMeasure at:fAt];
	[fView scrollMeasureToVisible:fMeasure];
}

- (void) highlightCursor
{
	std::string word = fSong->GetWord(fStanza, fMeasure, fAt);
	if (!word.size())
		[fView highlightLyricsInStanza:fStanza measure:fMeasure at:fAt];
}

@end

class VLCocoaFontHandler : public VLFontHandler {
public:
	VLCocoaFontHandler(NSString * name, float size);

	virtual void 	Draw(float x, float y, const char * utf8Text, bool highlight);
	virtual float	Width(const char * utf8Text);
private:
	NSDictionary *	fTextAttr;
};

VLCocoaFontHandler::VLCocoaFontHandler(NSString * name, float size)
{
	NSFont * font = [NSFont fontWithName:name size:size];
	
	fTextAttr = 
		[[NSDictionary alloc] initWithObjectsAndKeys:
			font, NSFontAttributeName, nil];
}

static NSColor * sHighlightColor;

void VLCocoaFontHandler::Draw(float x, float y, 
							  const char * utf8Text, bool highlight)
{
	NSDictionary * attr = fTextAttr;
	if (highlight) {
		NSMutableDictionary * aa =
			[NSMutableDictionary dictionaryWithDictionary:attr];
		[aa setValue:sHighlightColor forKey:NSBackgroundColorAttributeName];
		attr = aa;
	}	
	NSString * t 		= [NSString stringWithUTF8String:utf8Text];
	[t drawAtPoint:NSMakePoint(x,y) withAttributes:attr];
}

float VLCocoaFontHandler::Width(const char * utf8Text)
{
	NSString * t = [NSString stringWithUTF8String:utf8Text];
	NSSize	   sz= [t sizeWithAttributes:fTextAttr];

	return sz.width;
}

@implementation VLSheetView (Lyrics)

- (void) drawLyricsForSystem:(int)system stanza:(size_t)stanza
{
	static VLFontHandler * sRegularFont  = nil;
	static VLFontHandler * sNarrowFont 	 = nil;
	if (!sRegularFont) {
		sRegularFont = new VLCocoaFontHandler(@"Arial", 12.0f);
		sNarrowFont  = new VLCocoaFontHandler(@"ArialNarrow", 12.0f);
	}
	VLTextLayout			text(sRegularFont, sNarrowFont);

	const VLSong * 			song 	  	= [self song];
	const float 			kSystemY  	= [self systemY:system];
	const VLSystemLayout & 	kLayout	  	= (*fLayout)[system];
	const int				kFirstMeas	= fLayout->FirstMeasure(system);
	
	//
	// Build new list
	//
	for (int m = 0; m<kLayout.NumMeasures(); ++m) {
		int	measIdx = m+kFirstMeas;
		if (measIdx >= song->CountMeasures())
			break;
		const VLMeasure		measure = song->fMeasures[measIdx];
		const VLNoteList &	notes	= measure.fMelody;
		VLFraction at(0);
		for (VLNoteList::const_iterator note = notes.begin();
			 note != notes.end();
			 ++note
		) {
			if (note->fLyrics.size() < stanza 
             || !note->fLyrics[stanza-1].fText.size()
			) {
				;
			} else {
				if (!fHighlightNow) {
					fHighlightNow = stanza == fHighlightStanza
						&& measIdx == fHighlightMeasure
						&& at == fHighlightAt;
					if (fHighlightNow && !sHighlightColor) 
						sHighlightColor = 
							[[self textBackgroundColorForSystem:system]
								shadowWithLevel:0.2];
				}

				text.AddSyllable(note->fLyrics[stanza-1], 
								 [self noteXInMeasure:measIdx at:at],	
								 fHighlightNow);
				fHighlightNow = fHighlightNow && !fHighlightOne &&
					note->fLyrics[stanza-1].fKind & VLSyllable::kHasNext;
			}
			at += note->fDuration;
		}
	}

	text.DrawLine(kSystemY+kLyricsY-stanza*kLyricsH);
	sHighlightColor = nil;
}

- (void) editLyrics
{
	VLEditable * e	= 
		[[VLLyricsEditable alloc]
			initWithView:self
			song:[self song]
			stanza:fCursorStanza
			measure:fCursorMeasure
			at:fCursorAt];
	[self setEditTarget:e];
	[fFieldEditor selectText:self];
}

- (void) highlightLyricsInStanza:(size_t)stanza measure:(int)measure at:(VLFraction)at
{
	const float 	   	kSystemY = [self systemY:fLayout->SystemForMeasure(measure)];
	NSRect 				r 	   	 =
		NSMakeRect([self noteXInMeasure:measure at:at]-kNoteW*0.5f,
				   kSystemY+kLyricsY-stanza*kLyricsH, kNoteW, kLyricsH);
	[[NSColor colorWithCalibratedWhite:0.8f alpha:1.0f] setFill];
	NSRectFillUsingOperation(r, NSCompositePlusDarker);	
}

- (void) highlightTextInStanza:(size_t)stanza measure:(int)measure at:(VLFraction)at one:(BOOL)one
{
	fHighlightStanza = stanza;
	fHighlightMeasure= measure;
	fHighlightAt	 = at;
	fHighlightNow	 = false;
	fHighlightOne	 = one;
}

@end
