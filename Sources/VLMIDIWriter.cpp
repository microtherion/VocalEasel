//
// File: VLMIDIWriter.cpp
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2008-2018 Matthias Neeracher
//

#include "VLMIDIWriter.h"
#include <AudioToolbox/AudioToolbox.h>

VLMIDIUtilities::VLMIDIUtilities(MusicSequence music)
    : fMusic(music)
{
}

MusicTimeStamp VLMIDIUtilities::Length()
{	
	UInt32 ntracks;
	MusicSequenceGetTrackCount(fMusic, &ntracks);
	MusicTimeStamp sequenceLength = 0;
	for (UInt32 i = 0; i < ntracks; ++i) {
		MusicTrack track;
		MusicTimeStamp trackLength;
		UInt32 propsize = sizeof(MusicTimeStamp);
		MusicSequenceGetIndTrack(fMusic, i, &track);
		MusicTrackGetProperty(track, kSequenceTrackProperty_TrackLength,
							  &trackLength, &propsize);
		sequenceLength = std::max(sequenceLength, trackLength);
	}
	return sequenceLength;
}

MusicTimeStamp VLMIDIUtilities::Find(VLLocation at)
{
	UInt32 ntracks;
	MusicSequenceGetTrackCount(fMusic, &ntracks);
    MusicTrack track;
    MusicSequenceGetIndTrack(fMusic, ntracks-1, &track);
    MusicEventIterator iter;
    NewMusicEventIterator(track, &iter);
    Boolean hasEvent;
    while (!MusicEventIteratorHasCurrentEvent(iter, &hasEvent) && hasEvent) {
        MusicTimeStamp          ts;
        MusicEventType          ty;
        const VLMIDIUserEvent * data;
        UInt32                  sz;
        MusicEventIteratorGetEventInfo(iter, &ts, &ty, (const void **)&data, &sz);
        if (ty == kMusicEventType_User && data->fAt >= at)
            return ts;
        MusicEventIteratorNextEvent(iter);
    }
    return Length();
}

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

void VLMIDIWriter::VisitMeasure(uint32_t m, VLProperties & p, VLMeasure & meas)
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
        VLMIDIUserEvent	event = {12, n.fPitch, static_cast<uint8_t>(fStanza), n.fVisual, fAt};
		MusicTrackNewUserEvent(fTrack, fNoteTime, 
			 reinterpret_cast<const MusicEventUserData *>(&event));
	}
	fAt.fAt     = fAt.fAt+n.fDuration;
	fNoteTime	+= n.fDuration * (float)fTime.fDenom;	
}

void VLMIDIWriter::VisitChord(VLChord & c)
{
	if (c.fPitch != VLNote::kNoPitch) {
        VLMIDIUserEvent	event = {12, 0, static_cast<uint8_t>(fStanza), 0, fAt};
		MusicTrackNewUserEvent(fTrack, fChordTime, 
			 reinterpret_cast<const MusicEventUserData *>(&event));
	}
	fAt.fAt     = fAt.fAt+c.fDuration;
	fChordTime	+= c.fDuration * (float)fTime.fDenom;
}
