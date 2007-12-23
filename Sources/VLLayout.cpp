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

VLSystemLayout::VLSystemLayout(const VLProperties & prop, float width)
{
	fDivisions		= prop.fDivisions;
	fNumGroups		= prop.fTime.fNum / std::max(prop.fTime.fDenom / 4, 1);
	fDivPerGroup	= fDivisions * prop.fTime.fNum * 4 / (prop.fTime.fDenom * fNumGroups);
	fClefKeyWidth	= kClefX+kClefW+(std::labs(prop.fKey)+1)*kKeyW;
	fMeasureWidth	= fNumGroups*(fDivPerGroup+1)*kNoteW;
	fNumMeasures= std::max<int>(1, std::floor((width-fClefKeyWidth) / fMeasureWidth));
}

VLLayout::VLLayout(const VLSong & song, float width)
{
	for (size_t meas = 0; meas<song.fMeasures.size(); ) {
		const VLProperties & prop = song.fProperties[song.fMeasures[meas].fPropIdx];
		push_back(VLSystemLayout(prop, width));
		meas += back().NumMeasures();
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
