//
// File: VLLilypondWriter.h
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2007-2018 Matthias Neeracher
//

#include "VLModel.h"

class VLLilypondWriter: public VLSongVisitor {
public:
	VLLilypondWriter() {}

	void Visit(VLSong & song) override;
	void VisitMeasure(uint32_t m, VLProperties & p, VLMeasure & meas) override;
	void VisitNote(VLLyricsNote & n) override;
	void VisitChord(VLChord & c) override;

	const std::string & Chords() const { return fChords; }
	const std::string & Melody() const { return fMelody; }
	const std::string & Lyrics(size_t stanza) const { return fLyrics[stanza]; }
private:	
	std::string					fChords;
	std::string 				fMelody;
	std::vector<std::string> 	fLyrics;

	VLSong *					fSong;
	bool						fUseSharps;
	bool						fInPickup;
    bool                        fInSlur;
	bool						fAutomaticLayout;
	int							fPrevBreak;
	size_t						fSeenEnding;
    size_t                      fPrevTie;
    size_t                      fStartTie;
	int							fNumEndings;
	VLNote						fPrevNote;
	std::string					fAccum;
	std::string 				fIndent;
	std::vector<std::string> 	fL;
	VLProperties *				fLastProp;
};

// Local Variables:
// mode:C++
// End:
