//
// File: VLSheetViewSelection.h - Measure selection functionality
//
// Author(s):
//
//      (MN)    Matthias Neeracher
//
// Copyright © 2006-2007 Matthias Neeracher
//

@interface VLSheetView (Selection)

- (void)editSelection;
- (void)adjustSelection:(NSEvent *)event;

- (BOOL)validateUserInterfaceItem:(id)item;
- (IBAction)cut:(id)sender;
- (IBAction)copy:(id)sender;
- (IBAction)paste:(id)sender;
- (IBAction)delete:(id)sender;

- (IBAction)editRepeat:(id)sender;
- (IBAction)editRepeatEnding:(id)sender;
- (IBAction)insertStartCoda:(id)sender;
- (IBAction)insertJumpToCoda:(id)sender;
- (IBAction)insertBreak:(id)sender;

@end

// Local Variables:
// mode:ObjC
// End:
