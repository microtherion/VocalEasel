//
// File: VLLayout.cpp - Dimensions for lead sheet layout
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2007 Matthias Neeracher
//

#include "VLLayout.h"
#include "VLSheetViewInternal.h"

#include <algorithm>
#include <cstdlib>
#include <cmath>

VLSystemLayout::VLSystemLayout(const VLProperties & prop, float width, int maxMeas)
{
	fDivisions		= prop.fDivisions;
	fNumGroups		= prop.fTime.fNum / std::max(prop.fTime.fDenom / 4, 1);
	fDivPerGroup	= fDivisions * prop.fTime.fNum * 4 / (prop.fTime.fDenom * fNumGroups);
	fClefKeyWidth	= kClefX+kClefW+(std::labs(prop.fKey)+1)*kKeyW;
	fMeasureWidth	= fNumGroups*(fDivPerGroup+1)*kNoteW;
	fNumMeasures	= std::min(maxMeas,
							   std::max<int>(1, 
											 std::floor((width-fClefKeyWidth) / fMeasureWidth)));
}

static size_t NextBreak(const VLSong & song, size_t after=0)
{
	size_t propIdx = song.fMeasures[after].fPropIdx;
	while (++after < song.fMeasures.size())
		if (song.fMeasures[after].fBreak || song.fMeasures[after].fPropIdx != propIdx)
			return after;
	return song.fMeasures.size();
}

VLLayout::VLLayout(const VLSong & song, float width)
{
	size_t nextBreak = NextBreak(song);
	for (size_t meas = 0; meas<song.fMeasures.size(); ) {
		push_back(VLSystemLayout(song.Properties(meas), width, nextBreak-meas));
		meas += back().NumMeasures();
		if (meas >= nextBreak)
			nextBreak = NextBreak(song, nextBreak);
	}
}

int	VLLayout::FirstMeasure(int system) const
{
	int meas = 0;
	for (int sys=0; sys<system; ++sys)
		meas += (*this)[sys].NumMeasures();
	return meas;
}

int	VLLayout::SystemForMeasure(int measure) const
{
	int sys;
	for (sys=0; sys<size(); ++sys) {
		measure -= (*this)[sys].NumMeasures();
		if (measure < 0)
			break;
	} 
	return sys;
}

float VLLayout::MeasurePosition(int measure) const
{
	for (int sys=0; sys<size(); ++sys) {
		const VLSystemLayout & layout = (*this)[sys];
		if (measure < layout.NumMeasures()) 
			return layout.MeasurePosition(measure);
		measure -= layout.NumMeasures();
	}
	return 0.0f;
}

float VLLayout::NotePosition(int measure, VLFraction at) const
{
	for (int sys=0; sys<size(); ++sys) {
		const VLSystemLayout & layout = (*this)[sys];
		if (measure < layout.NumMeasures()) {
			int div = at.fNum*4*layout.Divisions() / at.fDenom;
			
			return layout.MeasurePosition(measure) 
				+ (div + div/layout.DivPerGroup() + 1)*kNoteW;
		}
		measure -= layout.NumMeasures();
	}
	return 0.0f;
}

VLFontHandler::~VLFontHandler()
{
}

VLTextLayout::VLTextLayout(VLFontHandler * regular, VLFontHandler * narrow)
	: fRegularFont(regular), fNarrowFont(narrow)
{
}

void VLTextLayout::AddSyllable(const VLSyllable & syll, float x)
{
	VLLayoutSyll ls;

	static_cast<VLSyllable &>(ls)    = syll;
	ls.fX = x;

	fSyllables.push_back(ls);
}

typedef std::vector<VLLayoutSyll>::iterator	VLSyllIter;

#define NARROW_SPACE "\xE2\x80\x89"
#define PRE_DASH     "-" NARROW_SPACE
#define POST_DASH    NARROW_SPACE "-"

void VLTextLayout::DrawLine(float y)
{
	if (fSyllables.empty())
		return;

	const float kDashW	= fRegularFont->Width("-");
	const float kSpaceW = fRegularFont->Width(NARROW_SPACE);
	VLSyllIter 	syll 	= fSyllables.begin();
	VLSyllIter 	end  	= fSyllables.end();
	float 		nextW   = fRegularFont->Width(syll->fText.c_str());
	float		nextX	= syll->fX-0.5*nextW;

	if (syll->fKind & VLSyllable::kHasPrev)
		fRegularFont->Draw(nextX-fRegularFont->Width(PRE_DASH), y, PRE_DASH);

	while (syll != end) {
		std::string text = syll->fText;
		VLSyllIter  next = syll+1;
		float       curW = nextW;
		float		curX = nextX;

		while (next != end) {
			nextW 	= fRegularFont->Width(next->fText.c_str());
			nextX 	= next->fX-0.5*nextW;
			if (next->fKind & VLSyllable::kHasPrev) {
				if (curX+curW+kDashW < nextX) {
					//
					// Plenty of space, draw dashes
					//
					float dashSpace = 0.5*(nextX-curX-curW-kDashW);
					fRegularFont->Draw(curX, y, text.c_str());
					fRegularFont->Draw(curX+curW+dashSpace, y, "-");

					goto nextText;
				} else {
					//
					// Fuse & continue
					//
					text   += next->fText;
					curW 	= fRegularFont->Width(text.c_str());
					if (++next != end) {
						nextW	= fRegularFont->Width(next->fText.c_str());
						nextX 	= next->fX-0.5*nextW;						
					}
				}
			} else {
				if (curX+curW+kSpaceW < nextX) {
					//
					// Enough space, draw regular
					//
					fRegularFont->Draw(curX, y, text.c_str());
				} else {
					//
					// Tight space, draw narrow & adjust
					//
					fNarrowFont->Draw(curX, y, text.c_str());
					text += NARROW_SPACE;
					nextX = std::max(nextX, curX+fNarrowFont->Width(text.c_str()));
				}
				goto nextText;
			}
		}
		//
		// At end of line
		//
		if ((end-1)->fKind & VLSyllable::kHasNext)
			text += POST_DASH;
		fRegularFont->Draw(curX, y, text.c_str());
	nextText:
		syll = next;
	}
}
