//
//  VLSheetViewInternal.h
//  Vocalese
//
//  Created by Matthias Neeracher on 1/4/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

const float kLineX		=  5.0;
const float kLineH  	= 10.0;
#define kSystemBaseline ((fNumBotLedgers+1)*kLineH+fNumStanzas*kLyricsH)
#define kSystemAscent	((fNumTopLedgers+7)*kLineH+kChordH)
#define kSystemH		(kSystemBaseline+kSystemAscent)
const float kClefX		= 20.5f;
const float kClefY		=-15.0f;
const float kClefW		= 30.0f;
const float kMeasTol	=  3.5f;
const float kMeasNoX	= 10.0f;
const float kMeasNoY	=  4.5f*kLineH;
const float kNoteW		= 12.0f;
const float kKeyW		= 10.0f;
const float kAccW		= 10.0f;
const float kSharpY		=-15.0f;
const float kFlatY		= -7.0f;
const float kNaturalY	=-15.0f;
const float kSharpW		=-11.0f;
const float kFlatW		= -9.0f;
const float kNaturalW	= -7.0f;
const float kImgScale	= 0.04f;
#define kChordY		   	((fNumTopLedgers+6)*kLineH)
const float kChordW		= 40.0f;
const float kChordH		= 25.0f;
#define kLyricsY  		(-(fNumBotLedgers+1)*kLineH)
const float kLyricsH	=  1.5*kLineH;
const float kNoteX		=  7.0f;
const float kNoteY		=  5.0f;
const float kStemX		=  0.0f;
const float kStemY		=  1.0f;
const float kStemH		= 30.0f;
const float kWholeRestY	= 20.0f;
const float kHalfRestY	= 15.0f;
const float kTieDepth	= 10.0f;
const float kCodaX		=-10.0f;
const float kCodaY		=  5.0f;
const float kLedgerX	=-10.0f;
const float kLedgerW	= 20.0f;
