//
// File: VLMIDIWriter.h
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2008-2011 Matthias Neeracher
//

#include "VLModel.h"
#include <CoreFoundation/CoreFoundation.h>
#include <AudioToolbox/AudioToolbox.h>

struct VLMIDIUserEvent {
	uint32_t	fLength;
	int8_t		fPitch;		// 0 -> Chord
	uint8_t		fStanza;
	int16_t		fMeasure;
    uint32_t    fVisual;
	VLFract		fAt;
};

class VLMIDIWriter: public VLSongVisitor {
public:
	VLMIDIWriter(MusicSequence music, size_t countIn) 
		: fMusic(music), fCountIn(countIn) {}

	virtual void Visit(VLSong & song);
	virtual void VisitMeasure(size_t m, VLProperties & p, VLMeasure & meas);
	virtual void VisitNote(VLLyricsNote & n);
	virtual void VisitChord(VLChord & c);
private:	
	MusicSequence			fMusic;
	size_t					fCountIn;
	MusicTrack				fTrack;
	size_t					fMeasure;
	size_t					fStanza;
	MusicTimeStamp			fChordTime;
	MusicTimeStamp			fNoteTime;
	VLFraction				fAt;
	VLFraction				fTime;
	std::vector<uint8_t>	fVolta;
};

// Local Variables:
// mode:C++
// End:
