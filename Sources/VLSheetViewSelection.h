//
//  VLSheetViewSelection.h
//  Vocalese
//
//  Created by Matthias Neeracher on 12/28/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
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

@end

// Local Variables:
// mode:ObjC
// End:
