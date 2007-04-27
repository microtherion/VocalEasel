/*
 *  VLModel.h
 *  Vocalese
 *
 *  Created by Matthias Neeracher on 12/18/05.
 *  Copyright 2005 __MyCompanyName__. All rights reserved.
 *
 */

#include <list>
#include <vector>
#include <string>
#include <inttypes.h>

const int 	kVLSharpChar	= 0x266F;
const int 	kVLFlatChar		= 0x266D;
#define		kVLSharpStr		"\xE2\x99\xAF"
#define		kVLFlatStr		"\xE2\x99\xAD"

struct VLFract {
	uint16_t	fNum;	// Numerator
	uint16_t	fDenom;	// Denominator
};

struct VLFraction : VLFract {
	VLFraction(uint16_t num = 0, uint16_t denom = 1, bool norm=false) 
		{ fNum = num; fDenom = denom; if (norm) Normalize(); }
	VLFraction(VLFract f) : VLFract(f) {}

	VLFraction & operator+=(VLFraction other);
	VLFraction & operator-=(VLFraction other);
	VLFraction & operator*=(VLFraction other);
	VLFraction & operator/=(VLFraction other);
	VLFraction & operator%=(VLFraction other);
private:
	VLFraction & Normalize();
};

inline float operator*(VLFraction f, float sc)
{
	return sc*f.fNum/f.fDenom;
}

inline VLFraction operator+(VLFraction one, VLFraction other)
{
	return one += other;
}

inline VLFraction operator-(VLFraction one, VLFraction other)
{
	return one -= other;
}

inline VLFraction operator*(VLFraction one, VLFraction other)
{
	return one *= other;
}

inline VLFraction operator/(VLFraction one, VLFraction other)
{
	return one /= other;
}

inline VLFraction operator%(VLFraction one, VLFraction other)
{
	return one %= other;
}

inline bool operator==(VLFraction one, VLFraction other)
{
	return one.fNum*other.fDenom == other.fNum*one.fDenom;
}

inline bool operator!=(VLFraction one, VLFraction other)
{
	return one.fNum*other.fDenom != other.fNum*one.fDenom;
}

inline bool operator<(VLFraction one, VLFraction other)
{
	return one.fNum*other.fDenom < other.fNum*one.fDenom;
}

inline bool operator>(VLFraction one, VLFraction other)
{
	return one.fNum*other.fDenom > other.fNum*one.fDenom;
}

inline bool operator<=(VLFraction one, VLFraction other)
{
	return one.fNum*other.fDenom <= other.fNum*one.fDenom;
}

inline bool operator>=(VLFraction one, VLFraction other)
{
	return one.fNum*other.fDenom >= other.fNum*one.fDenom;
}

class VLProperties;

struct VLSyllable {
	std::string	fText;	   // Syllable text
	uint8_t		fKind;     // Adjacency information
	enum {
		kSingle			= 0,
		kBegin			= 1,
		kEnd			= 2,
		kMiddle			= 3,
		kHasNext		= 1,
		kHasPrev		= 2
	};

	operator bool() const { return fText.size() > 0; }
};
	
struct VLNote {
	VLFraction 	fDuration;
	int8_t		fPitch;		// Semitones
	enum {
	    kNoPitch = -128,
	    kMiddleC = 60,
		kOctave	 = 12
	};
	//
	// We only allow ties BETWEEN measures. Within measures, we just store
	// a combined note length.
	//
	uint8_t		fTied;		// Tied with note in adjacent measure
	enum {
		kNotTied		= 0,
		kTiedWithNext	= 1,
		kTiedWithPrev	= 2
	};

	VLNote() : fPitch(kNoPitch) {}
	VLNote(VLFraction dur, int8_t pitch) 
		: fDuration(dur), fPitch(pitch), fTied(kNotTied)
	{}
	VLNote(std::string name);

	void Name(std::string & name, bool useSharps = false) const;
	void LilypondName(std::string & name, VLFraction at, VLFraction prevDur, VLFraction nextDur, bool & triplet, const VLProperties & prop) const;
	void MMAName(std::string & name, VLFraction at, VLFraction dur, VLFraction prevDur, VLFraction nextDur, const VLProperties & prop) const;
};

struct VLRest : VLNote {
	VLRest(VLFraction duration) : VLNote(duration, kNoPitch) {}
};

struct VLChord : VLNote {
	uint32_t	fSteps;		// Notes in chord, listed in semitones
	enum {
		kUnison	= 0,
		kMin2nd,
		kMaj2nd,
		kMin3rd,
		kMaj3rd,
		k4th,
		kDim5th,
		k5th,
		kAug5th,
		kDim7th,
		kMin7th,
		kMaj7th,
		kOctave,
		kMin9th,
		kMaj9th,
		kAug9th,
		kDim11th,
		k11th,
		kAug11th,
		kDim13th,
		kMin13th,
		kMaj13th,

		kmUnison	= (1 << kUnison),
		kmMin2nd	= (1 << kMin2nd),
		kmMaj2nd	= (1 << kMaj2nd),
		kmMin3rd	= (1 << kMin3rd),
        kmMaj3rd	= (1 << kMaj3rd),
		km4th		= (1 << k4th),
		kmDim5th	= (1 << kDim5th),
		km5th		= (1 << k5th),
		kmAug5th	= (1 << kAug5th),
		kmDim7th	= (1 << kDim7th),
		kmMin7th	= (1 << kMin7th),
		kmMaj7th	= (1 << kMaj7th),
		kmOctave	= (1 << kOctave),
		kmMin9th	= (1 << kMin9th),
		kmMaj9th	= (1 << kMaj9th),
		kmAug9th	= (1 << kAug9th),
		kmDim11th	= (1 << kDim11th),
		km11th		= (1 << k11th),
		kmAug11th	= (1 << kAug11th),
		kmDim13th	= (1 << kDim13th),
		kmMin13th	= (1 << kMin13th),
		kmMaj13th	= (1 << kMaj13th)
	};
	int8_t		fRootPitch;	// kNoPitch == no root
	
	VLChord() {}
	VLChord(std::string name);
	void	Name(std::string & base, std::string & ext, std::string & root, bool useSharps = false) const;
	void 	LilypondName(std::string & name, bool useSharps = false) const;
	bool 	MMAName(std::string & name, bool useSharps, bool initial) const;
};

struct VLProperties {
	VLFraction	fTime;		// Time (non-normalized)
	int8_t		fKey;		// Circle of fifths from C, >0 sharps, <0 flats
	int8_t		fMode;		// 1 = major -1 = minor
	int8_t		fDivisions;	// Number of divisions per quarter note
	
	//
	// Subdivide a note and adjust for swing
	//
	void PartialNote(VLFraction at, VLFraction totalDuration, bool grouped, VLFraction * noteDuration) const;  
	//
	// Determine visual representation of note head
	//
	void VisualNote(VLFraction at, VLFraction actualDur, bool prevTriplet, VLFraction *visualDur, bool * triplet) const;

	bool operator==(const VLProperties & other)
	{ return fTime == other.fTime && fKey == other.fKey && fMode == other.fMode
			&& fDivisions == other.fDivisions;
	}
};

struct VLLyricsNote : VLNote {
	VLLyricsNote() {}
	explicit VLLyricsNote(const VLNote & note) 
     	       { *static_cast<VLNote *>(this) = note; }

	std::vector<VLSyllable>	fLyrics;
};

typedef std::list<VLChord>		VLChordList;
typedef std::list<VLLyricsNote> VLNoteList;

struct VLMeasure {
	int8_t		fPropIdx;
	VLChordList fChords;
	VLNoteList 	fMelody;

	VLMeasure();

	void MMANotes(std::string & notes, const VLProperties & prop, VLFraction extra) const;
	void MMAChords(std::string & chords, const VLProperties & prop, bool initial) const;
};

struct VLRepeat {
	int8_t				fTimes;
	
	struct Ending {
		Ending(int8_t begin, int8_t end, uint16_t volta)
			: fBegin(begin), fEnd(end), fVolta(volta) {}
		int8_t		fBegin;
		int8_t		fEnd;
		uint16_t	fVolta;
	};
	std::vector<Ending>	fEndings;
};

struct VLSong {
	VLSong(bool initialize = true);
	void swap(VLSong & other);
	void clear();
	
	std::vector<VLProperties>	fProperties;
	std::vector<VLMeasure>		fMeasures;
	std::vector<VLRepeat>		fRepeats;
	int8_t						fGoToCoda;
	int8_t						fCoda;

	//
	// Iterate over measures in performance order
	//
	class iterator {
	public:
		size_t operator*() { return fMeasure; }
		iterator & operator++();
		bool operator==(const iterator & other) const { 
			return fMeasure==other.fMeasure && fStatus == other.fStatus;
		}
		bool operator!=(const iterator & other) const { 
			return fMeasure!=other.fMeasure || fStatus != other.fStatus;
		}
	protected:
		friend class VLSong;
		iterator(const VLSong & song, bool end);
	private:
		size_t					fMeasure;
		const VLSong &			fSong;
		struct Repeat {
			Repeat(size_t begin, int times) 
				: fBegin(begin), fTimes(times), fVolta(0) {}
			size_t	fBegin;
			int8_t	fTimes;
			int8_t	fVolta;

			bool operator==(const Repeat & other) const {
				return fBegin==other.fBegin && fVolta == other.fVolta;
			}
			bool operator!=(const Repeat & other) const {
				return fBegin!=other.fBegin || fVolta != other.fVolta;
			}
		};
		std::vector<Repeat>		fStatus;

		void AdjustStatus();
	};
	iterator 	begin() { return iterator(*this, false); }
	iterator 	end() 	{ return iterator(*this, true);  }

	void AddChord(VLChord chord, size_t measure, VLFraction at);
	void AddNote(VLLyricsNote note, size_t measure, VLFraction at);
	void DelChord(size_t measure, VLFraction at);
	void DelNote(size_t measure, VLFraction at);
	void ExtendNote(size_t measure, VLFraction at);
	void AddRepeat(size_t beginMeasure, size_t endMeasure, int times);
	void DelRepeat(size_t beginMeasure, size_t endMeasure);
	void AddEnding(size_t beginMeasure, size_t endMeasure, size_t volta);
	void DelEnding(size_t beginMeasure, size_t endMeasure);
	bool CanBeRepeat(size_t beginMeasure, size_t endMeasure, int * times = 0);
	bool CanBeEnding(size_t beginMeasure, size_t endMeasure, 
					 size_t * volta = 0, size_t * voltaOK = 0);
	bool DoesBeginRepeat(size_t measure, int * times = 0) const;
	bool DoesEndRepeat(size_t measure, int * times = 0) const;
	bool DoesBeginEnding(size_t measure, bool * repeat = 0, size_t * volta = 0) const;
	bool DoesEndEnding(size_t measure, bool * repeat = 0, size_t * volta = 0) const;
	bool IsNonEmpty() const;
	void Transpose(int semitones);

	bool FindWord(size_t stanza, size_t & measure, VLFraction & at);
	bool PrevWord(size_t stanza, size_t & measure, VLFraction & at);
	bool NextWord(size_t stanza, size_t & measure, VLFraction & at);
	std::string GetWord(size_t stanza, size_t measure, VLFraction at);
	void SetWord(size_t stanza, size_t measure, VLFraction at, std::string word,
				 size_t * nextMeas=0, VLFract * nextAt=0);

	enum {
		kInsert,
		kOverwriteChords = 1,
		kOverwriteMelody = 2
	};
	VLSong	CopyMeasures(size_t beginMeasure, size_t endMeasure);
	void	PasteMeasures(size_t beginMeasure, const VLSong & measures, 
						  int mode = kInsert);
	void	DeleteMeasures(size_t beginMeasure, size_t endMeasure);

	size_t	CountMeasures() const { return fMeasures.size(); }
	size_t  CountStanzas() const;
	size_t	CountTopLedgers() const;
	size_t	CountBotLedgers() const;
	void	LilypondNotes(std::string & notes) const;
	void	LilypondChords(std::string & chords) const;
	void 	LilypondStanza(std::string & lyrics, size_t stanza) const;
	VLFract TiedDuration(size_t measure);
};

// Local Variables:
// mode:C++
// End:
