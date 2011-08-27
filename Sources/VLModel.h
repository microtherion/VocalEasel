//
// File: VLModel.h - Represent music for a song.
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2005-2011 Matthias Neeracher
//

#include <list>
#include <vector>
#include <string>
#include <inttypes.h>

#pragma mark -
#pragma mark class VLFraction

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

#pragma mark -
#pragma mark class VLNote

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
		kTiedWithPrev	= 2,
	};
	//
	// Hint at visual representation (Computed in DecomposeNotes)
	//
	uint16_t 	fVisual;
	enum {
		kWhole          = 0,
		kHalf           = 1,
		kQuarter        = 2,
		kEighth         = 3,
		k16th           = 4,
		k32nd           = 5,
		
		kNoteHeadMask	= 0x0007,
        
		kWantSharp      = 0x10,
        kWant2Sharp     = 0x20,
        kPreferSharps   = 0x30, // kWantSharp   |   kWant2Sharp
		kWantFlat       = 0x40,
        kWant2Flat      = 0x80,
        kPreferFlats    = 0xC0, // kWantFlat    |   kWant2Flat
        kWantNatural    = 0x50, // kWantSharp   |   kWantFlat
        kNaturalOrSharp = 0x70, // kPreferSharps|   kWantFlat
        kNaturalOrFlat  = 0xD0, // kPreferFlats |   kWantSharp
        
		kAccidentalsMask= 0x00F0,
        
        kTriplet        = 0x300,
        
		kTupletMask     = 0x0F00
	};
	VLNote(VLFraction dur=0, int pitch=kNoPitch, uint16_t visual=0);
	VLNote(std::string name);
	std::string Name(uint16_t accidentals=0) const;
	void MakeRepresentable();
	void AlignToGrid(VLFraction at, VLFraction grid);
};

#pragma mark class VLSyllable

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

#pragma mark class VLLyricsNote

struct VLLyricsNote : VLNote {
	VLLyricsNote(const VLNote & note);
	VLLyricsNote(VLFraction dur=0, int pitch = kNoPitch, uint16_t visual=0);
    
	std::vector<VLSyllable>	fLyrics;
};


typedef std::list<VLLyricsNote> VLNoteList;

#pragma mark -
#pragma mark VLChord

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
    uint16_t    fRootAccidental;
	
	VLChord(VLFraction dur=0, int pitch=kNoPitch, int rootPitch=kNoPitch);
	VLChord(std::string name);
	void	Name(std::string & base, std::string & ext, std::string & root, uint16_t accidental=0) const;
};

typedef std::list<VLChord>		VLChordList;

#pragma mark class VLChordModifier

struct VLChordModifier {
	const char *	fName;
	uint32_t		fAddSteps;
	uint32_t		fDelSteps;
};

#pragma mark -
#pragma mark class VLProperties

struct VLProperties {
	VLFraction	fTime;		// Time (non-normalized)
	int8_t		fKey;		// Circle of fifths from C, >0 sharps, <0 flats
	int8_t		fMode;		// 1 = major -1 = minor
	int8_t		fDivisions;	// Number of divisions per quarter note
	std::string	fGroove;	// MMA Groove
    
	bool operator==(const VLProperties & other)
	{ return fTime == other.fTime && fKey == other.fKey && fMode == other.fMode
        && fDivisions == other.fDivisions && fGroove == other.fGroove;
	}
};

typedef std::vector<VLProperties>	VLPropertyList;

#pragma mark class VLMeasure

struct VLMeasure {
	enum {
		kNewSystem	= 1,
		kNewPage	= 2
	};
	uint8_t		fBreak;
	int8_t		fPropIdx;
	VLChordList fChords;
	VLNoteList 	fMelody;

	VLMeasure();

	bool IsEmpty() const;
	bool NoChords() const;

	void DecomposeNotes(const VLProperties & prop, VLNoteList & decomposed) const;
};

typedef std::vector<VLMeasure>		VLMeasureList;

#pragma mark class VLRepeat

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

typedef std::vector<VLRepeat>		VLRepeatList;

#pragma mark -
#pragma mark class VLSong

class VLSong {
public:
	VLSong(bool initialize = true);
	void swap(VLSong & other);
	void clear();
	
	VLPropertyList	fProperties;
	VLMeasureList	fMeasures;
	VLRepeatList	fRepeats;
	int8_t			fGoToCoda;
	int8_t			fCoda;

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
	VLNote ExtendNote(size_t measure, VLFraction at);
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
	bool DoesTieWithPrevRepeat(size_t measure) const;
	bool DoesTieWithNextRepeat(size_t measure) const;
	bool IsNonEmpty() const;
	void ChangeKey(int section, int newKey, int newMode, bool transpose);
	void ChangeOctave(int section, bool transposeUp);
	void ChangeDivisions(int section, int newDivisions);
	void ChangeTime(int section, VLFraction newTime);

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
	void	DeleteMeasures(size_t beginMeasure, size_t endMeasure, int mode = kInsert);
	size_t	CountMeasures() const { return fMeasures.size(); }
	size_t	EmptyEnding() const;
	size_t  CountStanzas() const;
	size_t	CountTopLedgers() const;
	size_t	CountBotLedgers() const;
	VLFract TiedDuration(size_t measure);
	VLProperties & Properties(size_t measure) {
		return fProperties[fMeasures[measure].fPropIdx];
	}
	const VLProperties & Properties(size_t measure) const {
		return fProperties[fMeasures[measure].fPropIdx];
	}
	void	SetProperties(size_t measure, int propIdx);

	bool 	DoesBeginSection(size_t measure) const;
	void	AddSection(size_t measure);
	void	DelSection(size_t measure);

	std::string PrimaryGroove() const;
private:
	void	AddMeasure();
};

#pragma mark class VLSongVisitor

class VLSongVisitor {
public:
	virtual ~VLSongVisitor();

	virtual void Visit(VLSong & song) 										{}
	virtual void VisitMeasure(size_t m, VLProperties & p, VLMeasure & meas) {}
	virtual void VisitNote(VLLyricsNote & n)								{}
	virtual void VisitChord(VLChord & c)									{}
protected:
	VLSongVisitor() {}

	void VisitMeasures(VLSong & song, bool performanceOrder);
	void VisitNotes(VLMeasure & measure, const VLProperties & prop, 
					bool decomposed);
	void VisitChords(VLMeasure & measure);
};

// Local Variables:
// mode:C++
// End:
