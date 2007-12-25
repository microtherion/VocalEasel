//
// File: VLLayout.h - Dimensions for lead sheet layout
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2007 Matthias Neeracher
//

#include <VLModel.h>
#include <vector>

class VLSystemLayout {
public:
	VLSystemLayout(const VLProperties & prop, float width, int maxMeas);

	float	ClefKeyWidth() 			const { return fClefKeyWidth; }
	float	MeasureWidth() 			const { return fMeasureWidth; }
	float   MeasurePosition(int m) 	const { return fClefKeyWidth+m*fMeasureWidth; }
	float   SystemWidth()  			const { return MeasurePosition(fNumMeasures); }
	int		Divisions()    const { return fDivisions;    }
	int		NumGroups()	   const { return fNumGroups;    }
	int 	DivPerGroup()  const { return fDivPerGroup;  }
	int		NumMeasures()  const { return fNumMeasures;  }
private:
	float	fClefKeyWidth;
	float 	fMeasureWidth;
	int		fDivisions;
	int		fNumGroups;
	int		fDivPerGroup;
	int		fNumMeasures;
};

class VLLayout : public std::vector<VLSystemLayout> {
public:
	VLLayout(const VLSong & song, float width);

	int	FirstMeasure(int system) const;
	int	SystemForMeasure(int measure) const;
	int	NumSystems() const	{ return size(); }
	float MeasurePosition(int measure) const;
	float NotePosition(int measure, VLFraction at) const;
};

class VLFontHandler {
public:
	virtual void 	Draw(float x, float y, const char * utf8Text) = 0;
	virtual float	Width(const char * utf8Text) = 0;
	virtual ~VLFontHandler();
};

struct VLLayoutSyll : public VLSyllable {
	float	fX;
};

class VLTextLayout {
public:
	VLTextLayout(VLFontHandler * regular, VLFontHandler * narrow);

	void AddSyllable(const VLSyllable & syll, float x);
	void DrawLine(float y);
private:
	VLFontHandler *				fRegularFont;
	VLFontHandler *				fNarrowFont;
	std::vector<VLLayoutSyll>	fSyllables;
};

// Local Variables:
// mode:C++
// End:
