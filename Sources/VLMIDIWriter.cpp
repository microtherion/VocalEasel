//
// File: VLMIDIWriter.cpp
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2008 Matthias Neeracher
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
	fVolta.clear();
	MusicSequenceNewTrack(fMusic, &fTrack);
	VLMetaEvent meta("VocalEasel");
	MusicTrackNewMetaEvent(fTrack, 0.0, &meta); 
	
	VisitMeasures(song, true);
}

void VLMIDIWriter::VisitMeasure(size_t m, VLProperties & p, VLMeasure & meas)
{
	if (fVolta.size() <= m)
		fVolta.push_back(0);
	fTime		= p.fTime;
	fMeasure	= m;
	fStanza		= ++fVolta[m];

	if (!m) 
		fChordTime = fNoteTime = fCountIn*fTime.fNum;
	
	fAt			= 0;
	VisitChords(meas);

	fAt			= 0;
	VisitNotes(meas, p, false);
}

void VLMIDIWriter::VisitNote(VLLyricsNote & n)
{
	if (n.fPitch != VLNote::kNoPitch && !(n.fTied & VLNote::kTiedWithPrev)) {
		VLMIDIUserEvent	event = {8, n.fPitch, fStanza, fMeasure, fAt};
		MusicTrackNewUserEvent(fTrack, fNoteTime, 
			 reinterpret_cast<const MusicEventUserData *>(&event));
	}
	fAt			+= n.fDuration;
	fNoteTime	+= n.fDuration * (float)fTime.fDenom;	
}

void VLMIDIWriter::VisitChord(VLChord & c)
{
	if (c.fPitch != VLNote::kNoPitch) {
		VLMIDIUserEvent	event = {8, 0, fStanza, fMeasure, fAt};
		MusicTrackNewUserEvent(fTrack, fChordTime, 
			 reinterpret_cast<const MusicEventUserData *>(&event));
	}
	fAt			+= c.fDuration;
	fChordTime	+= c.fDuration * (float)fTime.fDenom;
}
