//
// File: VLDebugFlags.h - Runtime debugging flags
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2007 Matthias Neeracher
//

#include <stdint.h>

class VLDebugFlags {
public:
	static void Update();
	static bool ShowDebugMenu()	{ return sFlags & 1; }
private:
	static uint32_t	sFlags;
};

// Local Variables:
// mode:C++
// End:

