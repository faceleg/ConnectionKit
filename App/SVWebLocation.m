//
//  SVWebLocation.m
//  Sandvox
//
//  Created by Mike on 04/05/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "KSWebLocation+SVWebLocation.h"


@implementation KSWebLocation (SVWebLocation)

@dynamic URL;
@dynamic title;

@end


// Function to expose KSWebLocation class method since only a protocol is availabl to plug-ins
NSArray *SVWebLocationGetReadablePasteboardTypes(NSPasteboard *pasteboard)
{
    return [KSWebLocation readableTypesForPasteboard:pasteboard];
}