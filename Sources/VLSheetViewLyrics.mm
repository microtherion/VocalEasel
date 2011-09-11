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

- (void)highlightWord
{
    VLLocation end = fSelection;
    if (!fSong->NextWord(fStanza, end))
        end.fMeasure = 1000;
    [fView highlightTextInStanza:fStanza start:fSelection end:end];
    std::string word = fSong->GetWord(fStanza, fSelection);
	fText = [[NSString alloc] initWithUTF8String:word.c_str()];
}

- (VLLyricsEditable *)initWithView:(VLSheetView *)view
							 song:(VLSong *)song 
							stanza:(int)stanza
							   at:(VLLocation)at
{
	self 		= [super init];
	fView		= view;
	fSong		= song;
	fStanza		= stanza;
	fSelection 	= at;
    fAnchor     = at;
 	fNext		= at;
	
	fSong->FindWord(fStanza, fSelection);
	[self highlightWord];
	
	return self;
}

- (void)dealloc
{
    [fText release];
}

- (NSString *) stringValue
{
    return fText;
}

- (void) setStringValue:(NSString *)val
{
	[[fView document] willChangeSong];
	fSong->SetWord(fStanza, fSelection, val ? [val UTF8String] : "", &fNext);
	[[fView document] didChangeSong];
}

- (BOOL) validValue:(NSString *)val
{
	return YES;
}

- (void) moveToNext
{
	if (fNext != fSelection) {
        fSelection  = fNext;
		fSong->FindWord(fStanza, fSelection);
	} else {
		if (!fSong->NextWord(fStanza, fSelection)) {
			fSelection.fMeasure	= 0;
			fSelection.fAt		= VLFraction(0);
			fSong->FindWord(fStanza, fSelection);
		}
	}
	fNext   = fSelection;
	[self highlightWord];
	[fView scrollMeasureToVisible:fSelection.fMeasure];
}

- (void) moveToPrev
{
	if (!fSong->PrevWord(fStanza, fSelection)) {
		fSelection.fMeasure = fSong->CountMeasures()-1;
		fSelection.fAt		= fSong->Properties(fSelection.fMeasure).fTime;
		fSong->PrevWord(fStanza, fSelection);
	}
    fNext   = fSelection;
	[self highlightWord];
	[fView scrollMeasureToVisible:fSelection.fMeasure];
}

- (void) highlightCursor
{
	std::string word = fSong->GetWord(fStanza, fSelection);
	if (!word.size())
		[fView highlightLyricsInStanza:fStanza at:fSelection];
}

- (BOOL)canExtendSelection:(VLRegion)region
{
    return region == kRegionLyrics;
}

- (void)extendSelection:(VLLocation)at
{
    if (!fSong->FindWord(fStanza, at))
        return;
    if (at < fAnchor) {
        //
        // Backward from anchor
        //
        fSelection  = at;
        at          = fAnchor;
    } else {
        //
        // Forward from anchor
        //
        fSelection  = fAnchor;
        fSong->FindWord(fStanza, fSelection);
    }
    if (!fSong->NextWord(fStanza, at))
        at.fMeasure = 1000;
    [fView highlightTextInStanza:fStanza start:fSelection end:at];
    std::string text;
    VLLocation  textAt   = fSelection;
    while (textAt < at) {
        if (text.size())
            text += ' ';
        text += fSong->GetWord(fStanza, textAt);
        fSong->NextWord(fStanza, textAt);
    }
    [fText release];
	fText = [[NSString alloc] initWithUTF8String:text.c_str()];
    [fView updateEditTarget];
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
		VLLocation          at      = {measIdx, VLFraction(0)};
		for (VLNoteList::const_iterator note = notes.begin();
			 note != notes.end();
			 ++note
		) {
			if (note->fLyrics.size() < stanza 
             || !note->fLyrics[stanza-1].fText.size()
			) {
				;
			} else {
                bool highlight = stanza == fHighlightStanza
                  && at >= fHighlightStart && at < fHighlightEnd;
                if (highlight && !sHighlightColor) 
                    sHighlightColor = [[self textBackgroundColorForSystem:system] shadowWithLevel:0.2];

				text.AddSyllable(note->fLyrics[stanza-1], 
								 [self noteXAt:at],	
								 highlight);
			}
			at.fAt = at.fAt+note->fDuration;
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
			at:fCursorLocation];
	[self setEditTarget:e];
	[fFieldEditor selectText:self];
}

- (void) highlightLyricsInStanza:(size_t)stanza at:(VLLocation)at
{
	const float 	   	kSystemY = [self systemY:fLayout->SystemForMeasure(at.fMeasure)];
	NSRect 				r 	   	 =
		NSMakeRect([self noteXAt:at]-kNoteW*0.5f,
				   kSystemY+kLyricsY-stanza*kLyricsH, kNoteW, kLyricsH);
	[[NSColor colorWithCalibratedWhite:0.8f alpha:1.0f] setFill];
	NSRectFillUsingOperation(r, NSCompositePlusDarker);	
}

- (void) highlightTextInStanza:(size_t)stanza start:(VLLocation)start end:(VLLocation)end
{
	fHighlightStanza    = stanza;
	fHighlightStart     = start;
    fHighlightEnd       = end;
    [self setNeedsDisplay:YES];
}

@end
