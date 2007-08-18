//
// File: VLDebugFlags.cpp - Runtime debugging flags
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2007 Matthias Neeracher
//

#include "VLDebugFlags.h"
#include <stdlib.h>

uint32_t VLDebugFlags::sFlags = 0;

void VLDebugFlags::Update()
{	
	const char * dbg = getenv("VOCALEASEL_DEBUG");

	if (dbg)
		sFlags = atoi(dbg);
}
