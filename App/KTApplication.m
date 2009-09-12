//
//  KTApplication.m
//  Marvel
//
//  Created by Terrence Talbot on 10/2/04.
//  Copyright 2004-2009 Karelia Software. All rights reserved.
//

/*
PURPOSE OF THIS CLASS/CATEGORY:
	Override methods to clean up when we exit

TAXONOMY AND RELATIONSHIP TO OTHER CLASSES:
	Subclass NSApplication

IMPLEMENTATION NOTES & CAUTIONS:
	x

 */

#import "KTApplication.h"
#import "KTAppDelegate.h"


@implementation KTApplication

- (void)orderFrontStandardAboutPanel:(id)sender
{
    // suppress Version so that about panel just displays CFBundleShortVersionString
    // putting all info in CFBundleShortVersionString allows Snow Leopard's Finder
    // to continue to display complete information in info panel 
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"", @"Version",
                             nil];
    [self orderFrontStandardAboutPanelWithOptions:options];
}

@end

