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
	void LilypondName(std::string & name, VLFraction at, const VLProperties & prop) const;
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
};

struct VLProperties {
	VLFraction	fTime;		// Time (non-normalized)
	int8_t		fKey;		// Circle of fifths from C, >0 sharps, <0 flats
	int8_t		fMode;		// 1 = major -1 = minor
	int8_t		fDivisions;	// Number of divisions per quarter note
	
	//
	// Subdivide a note and adjust for swing
	//
	void PartialNote(VLFraction at, VLFraction totalDuration, VLFraction * noteDuration) const;  
	//
	// Determine visual representation of note head
	//
	void VisualNote(VLFraction at, VLFraction actualDur, VLFraction *visualDur, bool * triplet) const;
};

struct VLSyllable {
	std::string	fText;
	bool		fHyphen;	// Followed by hyphen
};

typedef std::list<VLChord>		VLChordList;
typedef std::list<VLNote> 		VLNoteList;
typedef std::list<VLSyllable> 	VLSyllList;

struct VLMeasure {
	VLProperties *	fProperties;
	VLChordList		fChords;
	VLNoteList		fMelody;
	VLSyllList		fLyrics;

	VLMeasure();
};

struct VLSong {
	VLSong();
	
	std::list<VLProperties>	fProperties;
	std::vector<VLMeasure>	fMeasures;

	void AddChord(VLChord chord, size_t measure, VLFraction at);
	void AddNote(VLNote note, size_t measure, VLFraction at);
	void DelChord(size_t measure, VLFraction at);
	void DelNote(size_t measure, VLFraction at);
	void Transpose(int semitones);

	size_t	CountMeasures() const { return fMeasures.size(); }
	void	LilypondNotes(std::string & notes) const;
	void	LilypondChords(std::string & chords) const;
};

// Local Variables:
// mode:C++
// End:
