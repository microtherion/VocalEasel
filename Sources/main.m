//
//  main.m
//  Vocalese
//
//  Created by Matthias Neeracher on 12/17/05.
//  Copyright __MyCompanyName__ 2005 . All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "VLSoundSched.h"

int main(int argc, char *argv[])
{
	[VLSoundSched setup];
    return NSApplicationMain(argc, (const char **) argv);
}
