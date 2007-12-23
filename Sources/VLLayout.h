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

// Local Variables:
// mode:C++
// End:
