//
// File: VLLilypondWriter.h
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2007 Matthias Neeracher
//

#include "VLModel.h"

class VLLilypondWriter: public VLSongVisitor {
public:
	VLLilypondWriter() {}

	virtual void Visit(VLSong & song);
	virtual void VisitMeasure(size_t m, VLProperties & p, VLMeasure & meas);
	virtual void VisitNote(VLLyricsNote & n);
	virtual void VisitChord(VLChord & c);

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
	bool						fAutomaticLayout;
	int							fNumPickup;
	size_t						fSeenEnding;
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
