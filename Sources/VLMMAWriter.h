//
// File: VLMMAWriter.h
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2007 Matthias Neeracher
//

#include "VLModel.h"

class VLMMAWriter: public VLSongVisitor {
public:
	VLMMAWriter() {}

	virtual void Visit(VLSong & song);
	virtual void VisitMeasure(size_t m, VLProperties & p, VLMeasure & meas);
	virtual void VisitNote(VLLyricsNote & n);
	virtual void VisitChord(VLChord & c);

	const std::string & Measures() const { return fMeasures; }
private:	
	std::string					fMeasures;

	VLSong *					fSong;
	bool						fUseSharps;
	bool						fTied;
	bool						fInitial;
	int							fMeas;
	size_t						fLastDur;
	std::string					fAccum;
};

// Local Variables:
// mode:C++
// End:
