//
// File: VLLilypondWriter.h
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2007-2018 Matthias Neeracher
//

#include "VLLilypondWriter.h"
#include "VLPitchName.h"

void VLLilypondWriter::Visit(VLSong & song)
{
	fSong	= &song;
	fChords.clear();
	fMelody.clear();
	fLyrics.clear();
	fLyrics.resize(song.CountStanzas());
	fL			= fLyrics;
	fInPickup	= true;
	fIndent.clear();
	fSeenEnding	= 0;
	fNumEndings	= 0;
	fLastProp   = 0;
	fPrevBreak	= 0;
	
	fAutomaticLayout = true;
	for (int i=0; i<song.fMeasures.size(); ++i)
		if (song.fMeasures[i].fBreak & VLMeasure::kNewSystem) {
			fAutomaticLayout = false;
			break;
		}

	VisitMeasures(song, false);
	//
	// Terminate melody
	//
	if (fIndent.size())
		fMelody	+= fSeenEnding ? "}}\n" : "}\n";
}

void VLLilypondWriter::VisitMeasure(uint32_t m, VLProperties & p, VLMeasure & meas) 
{
	char measNo[8];	
	if (!(m % 4))
		sprintf(measNo, " %% %lu", m+1);
	else 	
		measNo[0] = 0;

	fUseSharps	= p.fKey > 0;
    fInPickup   = fInPickup && !m && meas.NoChords();
	if (fInPickup)
		++fPrevBreak;
    fInPickup   = fInPickup && meas.CanSkipRests();

	//
	// Generate chords
	//
	fAccum.clear();
	VisitChords(meas);
	fAccum += measNo;
	fChords+= fAccum + '\n';

	fAccum.clear();
	//
	// Generate key/time if changed
	//
	if (!fLastProp || fLastProp->fTime != p.fTime) {
		char time[16];
		sprintf(time, "\\time %d/%d\n", p.fTime.fNum, p.fTime.fDenom);
		fAccum += fIndent+time;
	}
	if (!fLastProp || fLastProp->fKey != p.fKey || fLastProp->fMode != p.fMode) {
		const int kMajorOffset 	= 6;
		const int kMinorOffset  = 9;

		static const char * sKeyNames[] = {
			"ges", "des", "as", "es", "bes", "f",
			"c", "g", "d", "a", "e", "b", "fis", "cis", "gis"
		};
		char key[16];
		if (p.fMode < 0)
			sprintf(key, "\\key %s \\minor\n", sKeyNames[p.fKey+kMinorOffset]);
		else
			sprintf(key, "\\key %s \\major\n", sKeyNames[p.fKey+kMajorOffset]);
		fAccum += fIndent+key;
	}
	fLastProp = &p;
	//
	// Generate structure elements
	//
	int		times;
	size_t	volta;
	bool	repeat;
	bool    hasBarLine = false;

	if (meas.fBreak & VLMeasure::kNewPage) {
		fAccum 		+= fIndent+"\\pageBreak\n";
		hasBarLine 	 = true;
		fPrevBreak 	 = m;
	} else if ((meas.fBreak & VLMeasure::kNewSystem)
			|| (fAutomaticLayout && m == fPrevBreak+4)
	) {
		fAccum 		+= fIndent+"\\break\n";
		hasBarLine 	 = true;
		fPrevBreak	 = m;
	}
	if (fSong->DoesEndRepeat(m)) {
		fAccum 	   += "}\n";
		fIndent 	= "";
		hasBarLine	= true;
	}
	if (fSong->DoesBeginEnding(m, &repeat, &volta)) {
		fAccum += fSeenEnding ? "}{\n" : "} \\alternative {{\n";
		fAccum += "    \\set Score.repeatCommands = #'((volta \"";
		const char * comma = "";
		for (int r=0; r<8; ++r)
			if (volta & (1<<r)) {
				char volta[8];
				sprintf(volta, "%s%d.", comma, r+1);
				comma	= ", ";
				fAccum += volta;
			}
		fAccum += "\")" + std::string(repeat ? "" : " end-repeat") + ")\n";
		fSeenEnding	|= volta;
		++fNumEndings;
		hasBarLine 	 = true;
	} else if (fSong->DoesEndEnding(m, &hasBarLine)) {
		fAccum += "}}\n";
		fIndent = "";
	}
	if (fSong->DoesBeginRepeat(m, &times)) {
		char volta[8];
		sprintf(volta, "%d", times);
		fAccum 	    = fAccum + "\\repeat volta "+volta+" {\n";
		fIndent 	= "    ";
		fSeenEnding = 0;
		fNumEndings	= 0;
		hasBarLine 	= true;
	}
	fAccum += fIndent;
	if (fSong->fCoda == m) {
		if (!hasBarLine)
			fAccum += "\\bar \"|.\" ";
		fAccum += "\\break \\mark \\markup { \\musicglyph #\"scripts.coda\" }\n"
			+ fIndent;
	}
	fMelody += fAccum;

	//
	// Generate melody & lyrics
	//
	fAccum.clear();
	for (size_t stanza=0; stanza<fL.size(); ++stanza)
		fL[stanza].clear();
	fPrevNote.fPitch = VLNote::kNoPitch;
	VisitNotes(meas, p, true);

	//
	// Consolidate triplets and dots
	//
	size_t trip;
	while ((trip = fAccum.find("} \\times 2/3 { ")) != std::string::npos)
		fAccum.erase(trip, 15);
	while ((trip = fAccum.find(" ~ } \\times 2/3 { ")) != std::string::npos)
		fAccum.erase(trip+2, 17);
	while ((trip = fAccum.find("~.")) != std::string::npos)
		fAccum.erase(trip, 1);
    while ((trip = fAccum.find("~(.")) != std::string::npos)
        fAccum.replace(trip, 3, ".(");

	if (fSong->fGoToCoda == m+1)
		fAccum += "\n"
			+ fIndent 
			+ "\\mark \\markup { \\musicglyph #\"scripts.coda\" } |";
	else
		fAccum += " |";
	fMelody	+= fAccum + measNo + '\n';

	//
	// Accumulate lyrics
	//
	const char * nuline = m%4 ? "" : "\n";
	for (size_t stanza=0; stanza<fLyrics.size(); ++stanza)
		fLyrics[stanza] += fL[stanza] + nuline;
}

static const char kValue[] = {
	1, 2, 4, 8, 16, 32
};

static std::string EscapeSyllable(std::string syll)
{
	bool seenAlpha = false;
	for (size_t i=0; i<syll.size(); ++i)
		if (isalpha(syll[i])) {
			seenAlpha = true;
			continue;
		} else {
			switch (syll[i]) {
			case '-':
			case ':':
			case '.':
			case ',':
			case ';':
			case '\'':
			case '_':
				if (seenAlpha)
					continue;
				/* Else fall through */
			default:
				goto escape;
			}
		}
	//
	// Purely alphabetic syllable, no need to escape.
	//
	return syll;

 escape:
	size_t q=0;
	while ((q = syll.find_first_of('\\', q)) != std::string::npos) {
		syll.replace(q, 1, "\\\\", 2);
		q += 2;
	}
	q = 0;
	while ((q = syll.find_first_of('"', q)) != std::string::npos) {
		syll.replace(q, 1, "\\\"", 2);
		q += 2;
	}
	q = 0;
	while ((q = syll.find_first_of('_', q)) != std::string::npos) {
		syll.replace(q, 1, "\"_\"", 3);
		q += 3;
	}
	return '"'+syll+'"';
}

static bool PreferSharps(bool globalSharps, int noteAccidentals)
{
	return (noteAccidentals & VLNote::kAccidentalsMask)
		? (noteAccidentals & VLNote::kWantSharp)
		: globalSharps;
}

void VLLilypondWriter::VisitNote(VLLyricsNote & n)							   
{
    int octave;
	std::string nm = VLPitchName(n.fPitch, n.fVisual, &octave, kVLLilypondNames);
	if (n.fPitch != VLNote::kNoPitch) {
		for (int ticks = octave+1; ticks>0; --ticks)
			nm += '\'';
		for (int commas = -1-octave; commas>0; --commas)
			nm += ',';
		fInPickup = false;
	} else if (fInPickup && n.fDuration.IsPowerOfTwo()) {
		nm = "s";
	}
	const char * space = fAccum.size() ? " " : "";
	const char * tie;
    switch (n.fTied & (VLNote::kTiedWithNext|VLNote::kSlurWithNext|VLNote::kStartSlur|VLNote::kEndSlur)) {
    case VLNote::kTiedWithNext|VLNote::kSlurWithNext|VLNote::kStartSlur:
        tie = "(";
        break;
    case VLNote::kTiedWithNext|VLNote::kStartSlur:
        tie = "~(";
        break;
    case VLNote::kTiedWithNext:
        tie = "~";
        break;
    case VLNote::kEndSlur:
        tie = ")";
        break;
    case VLNote::kTiedWithNext|VLNote::kSlurWithNext:
    default:
        tie = "";
        break;
    }
	char duration[32];
    if ((n.fTied & VLNote::kTiedWithPrev) && n.fVisual == fPrevNote.fVisual+1
		&& n.fPitch == fPrevNote.fPitch
    ) {
		strcpy(duration, ".");
    } else if (n.fVisual & VLNote::kTupletMask) {
        sprintf(duration, "%s\\times %d/%d { %s%d%s }",
                space, VLNote::TupletDenom(n.fVisual), VLNote::TupletNum(n.fVisual),
                nm.c_str(), kValue[n.fVisual & VLNote::kNoteHeadMask], tie);
    } else {
        sprintf(duration, "%s%s%d%s",
                space, nm.c_str(), kValue[n.fVisual & VLNote::kNoteHeadMask], tie);
    }
    fAccum     += duration;
	fPrevNote   = n;

    if (n.fPitch != VLNote::kNoPitch && !(n.fTied & VLNote::kTiedWithPrev)) {
        for (size_t i=0; i<fL.size(); ++i) {
			if (n.fLyrics.size() <= i || !n.fLyrics[i]) {
				fL[i] += " \\skip1";
			} else {
				fL[i] += ' ' + EscapeSyllable(n.fLyrics[i].fText);
				if (n.fLyrics[i].fKind & VLSyllable::kHasNext)
					fL[i] += " --";
			}
        }
    }
}

static const char * kLilypondStepNames[] = {
	"", "", "sus2", "", "", "sus", "5-", "", "5+", "6", "7", "7+", "",
	"9-", "9", "9+", "", "11", "11+", "", "13-", "13"
};

void VLLilypondWriter::VisitChord(VLChord & c)									
{
	std::string name = VLPitchName(c.fPitch, c.fVisual, 0, kVLLilypondNames);
    if (name == "r")
        name = "s";
	char duration[16];
	if (c.fDuration.IsPowerOfTwo()) 
		sprintf(duration, "%d", c.fDuration.fDenom);
	else
		sprintf(duration, "1*%d/%d", c.fDuration.fNum, c.fDuration.fDenom);
	name += std::string(duration);
	std::string ext;
	uint32_t steps = c.fSteps;
	if (c.fPitch == VLNote::kNoPitch)
		goto done;

	//
	// m / dim
	//
	if (steps & VLChord::kmMin3rd)
		if (steps & (VLChord::kmDim5th|VLChord::kmDim7th) 
		 && !(steps & (VLChord::km5th|VLChord::kmMin7th|VLChord::kmMaj7th|VLChord::kmMin9th|VLChord::kmMaj9th|VLChord::km11th|VLChord::kmAug11th|VLChord::kmMin13th|VLChord::kmMaj13th))
		) {
			ext = "dim";
			steps|= (steps & VLChord::kmDim7th) << 1;
			steps&=	~(VLChord::kmMin3rd|VLChord::kmDim5th|VLChord::kmDim7th);
		} else {
			ext = "m";
			steps&= ~VLChord::kmMin3rd;
		}
	steps &= ~(VLChord::kmUnison | VLChord::km5th);
	//
	// Maj
	//
	if (steps & VLChord::kmMaj7th) {
		bool hasMinor = ext.size();
		ext += hasMinor ? "7+" : "maj"; 
		if (steps & VLChord::kmMaj9th) {
			ext += hasMinor ? ".9" : "9";	
			steps &= ~VLChord::kmMaj9th;
		} else
			ext += hasMinor ? "" : "7";
		steps&= ~VLChord::kmMaj7th;
	}
	//
	// Sus
	//
	if (steps & (VLChord::kmMaj2nd|VLChord::km4th)) {
		if (ext.size())
			ext += '.';
		ext += "sus";
		if (steps & VLChord::kmMaj2nd)
			ext += "2";
		else
			ext += "4";
		steps&= ~(VLChord::kmMaj2nd|VLChord::km4th);
	}
	//
	// 6/9
	//
	if ((steps & (VLChord::kmDim7th|VLChord::kmMaj9th)) == (VLChord::kmDim7th|VLChord::kmMaj9th)) {
		if (ext.size() && !isalpha(ext[ext.size()-1]))
			ext += '.';
		ext += "6.9";
		steps&= ~(VLChord::kmDim7th|VLChord::kmMaj9th);
	}
	//
	// Other extensions. Only the highest unaltered extension is listed.
	//
	if (uint32_t unaltered = steps & (VLChord::kmMin7th|VLChord::kmMaj9th|VLChord::km11th|VLChord::kmMaj13th)) {
		steps			  &= ~unaltered;
	
		for (int step = VLChord::kMaj13th; step > VLChord::kDim7th; --step)
			if (unaltered & (1 << step)) {
				std::string sn = kLilypondStepNames[step];
				if (ext.size() && !isalpha(ext[ext.size()-1]) && sn.size())
					ext += '.';
				ext += sn;
				break;
			}
	}
	for (int step = VLChord::kMin2nd; steps; ++step) 
		if (steps & (1 << step)) {
			std::string sn = kLilypondStepNames[step];
			if (ext.size() && !isalpha(ext[ext.size()-1]) && sn.size())
				ext += '.';
			ext   += sn;
			steps &= ~(1 << step);
		}
	
	if (ext.size())
		name += ':' + ext;
	//
	// Root
	//
	if (c.fRootPitch != VLNote::kNoPitch)
		name += "/+" + VLPitchName(c.fRootPitch, c.fRootAccidental, 0, kVLLilypondNames);

 done:
	if (fAccum.size())
		fAccum += ' ';
	fAccum	+= name;
}
