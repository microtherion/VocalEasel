//
// File: VLMIDIWriter.h
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2008-2018 Matthias Neeracher
//

#include "VLModel.h"
#include <CoreFoundation/CoreFoundation.h>
#include <AudioToolbox/AudioToolbox.h>

struct VLMIDIUserEvent {
	uint32_t	fLength;
	int8_t		fPitch;		// 0 -> Chord
	uint8_t		fStanza;
    uint16_t    fVisual;
	VLLocation  fAt;
};

class VLMIDIUtilities {
public:
    VLMIDIUtilities(MusicSequence music);
    
    MusicTimeStamp  Length();
    MusicTimeStamp  Find(VLLocation at);
public:
    MusicSequence   fMusic;
};

class VLMIDIWriter: public VLSongVisitor {
public:
	VLMIDIWriter(MusicSequence music, size_t countIn) 
		: fMusic(music), fCountIn(countIn) {}

	void Visit(VLSong & song) override;
	void VisitMeasure(uint32_t m, VLProperties & p, VLMeasure & meas) override;
	void VisitNote(VLLyricsNote & n) override;
	void VisitChord(VLChord & c) override;
private:	
	MusicSequence			fMusic;
	size_t					fCountIn;
	MusicTrack				fTrack;
	size_t					fStanza;
	MusicTimeStamp			fChordTime;
	MusicTimeStamp			fNoteTime;
	VLLocation				fAt;
	VLFraction				fTime;
	std::vector<uint8_t>	fVolta;
};

// Local Variables:
// mode:C++
// End:
