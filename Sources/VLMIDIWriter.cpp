//
// File: VLMIDIWriter.cpp
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2008-2011 Matthias Neeracher
//

#include "VLMIDIWriter.h"
#include <AudioToolbox/AudioToolbox.h>

struct VLMetaEvent : MIDIMetaEvent {
	char fPadding[32];
	
	VLMetaEvent(const char * label) 
	{
		metaEventType	= 3;
		dataLength		= strlen(label);
		memcpy(data, label, dataLength);
	}
};

void VLMIDIWriter::Visit(VLSong & song)
{
	fChordTime = 0.0f;
	fVolta.clear();
	MusicSequenceNewTrack(fMusic, &fTrack);
	VLMetaEvent meta("VocalEasel");
	MusicTrackNewMetaEvent(fTrack, 0.0, &meta); 
	
	VisitMeasures(song, true);
}

void VLMIDIWriter::VisitMeasure(size_t m, VLProperties & p, VLMeasure & meas)
{
    const VLLocation kStartOfMeasure = {m, VLFraction(0)};
	if (fVolta.size() <= m)
		fVolta.push_back(0);
	fTime		= p.fTime;
	fStanza		= ++fVolta[m];

	if (!fChordTime) 
		fChordTime = fNoteTime = fCountIn*fTime.fNum;
	
	fAt			= kStartOfMeasure;
	VisitChords(meas);

	fAt			= kStartOfMeasure;
	VisitNotes(meas, p, false);
}

void VLMIDIWriter::VisitNote(VLLyricsNote & n)
{
	if (!(n.fTied & VLNote::kTiedWithPrev)) {
		VLMIDIUserEvent	event = {12, n.fPitch, fStanza, n.fVisual, fAt};
		MusicTrackNewUserEvent(fTrack, fNoteTime, 
			 reinterpret_cast<const MusicEventUserData *>(&event));
	}
	fAt.fAt     = fAt.fAt+n.fDuration;
	fNoteTime	+= n.fDuration * (float)fTime.fDenom;	
}

void VLMIDIWriter::VisitChord(VLChord & c)
{
	if (c.fPitch != VLNote::kNoPitch) {
		VLMIDIUserEvent	event = {12, 0, fStanza, 0, fAt};
		MusicTrackNewUserEvent(fTrack, fChordTime, 
			 reinterpret_cast<const MusicEventUserData *>(&event));
	}
	fAt.fAt     = fAt.fAt+c.fDuration;
	fChordTime	+= c.fDuration * (float)fTime.fDenom;
}
