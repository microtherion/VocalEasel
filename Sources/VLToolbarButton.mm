//
//  VLToolbarButton.mm
//  VocalEasel
//
//  Created by Matthias Neeracher on 8/23/11.
//  Copyright 2011 Matthias Neeracher. All rights reserved.
//

#import "VLToolbarButton.h"

@implementation VLToolbarButton

- (void)awakeFromNib
{
    NSButtonCell * cell = [self cell];
    [cell setHighlightsBy:NSPushInCellMask];
    [cell setShowsStateBy:NSContentsCellMask];
    [cell setBackgroundStyle:NSBackgroundStyleRaised];
}

@end
