//
// File: VLSheetViewSelection.h - Measure selection functionality
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2006-2011 Matthias Neeracher
//

#import "VLMIDIWriter.h"

@interface VLSheetView (Selection)

- (void)editSelection:(BOOL)extend;
- (void)adjustSelection:(NSEvent *)event;
- (NSRange)sectionsInSelection;

- (BOOL)validateUserInterfaceItem:(id)item;
- (IBAction)cut:(id)sender;
- (IBAction)copy:(id)sender;
- (IBAction)paste:(id)sender;
- (IBAction)delete:(id)sender;
- (IBAction)insertMeasure:(id)sender;

- (IBAction)editRepeat:(id)sender;
- (IBAction)editRepeatEnding:(id)sender;
- (IBAction)insertStartCoda:(id)sender;
- (IBAction)insertJumpToCoda:(id)sender;
- (IBAction)insertBreak:(id)sender;

- (void)updateKeyMenu;
- (void)updateTimeMenu;
- (void)updateDivisionMenu;
- (void)updateGrooveMenu;

- (void)updateMenus;

- (void) willPlaySequence:(MusicSequence)music;

@end

// Local Variables:
// mode:ObjC
// End:
