//
//  KTDocWindowController+Accessors.m
//  Marvel
//
//  Created by Dan Wood on 5/5/05.
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import "KTDocWindowController.h"

#import "KTDocWebViewController.h"
#import "KTPage.h"
#import "NSManagedObjectContext+KTExtensions.h"

#import <QuartzCore/QuartzCore.h>


// GENERIC, NO-BIG-WHOOP ACCESSORS ONLY.  PUT ANYTHING WITH LOGIC IN A DIFFERENT FILE PLEASE.


@implementation KTDocWindowController ( Accessors )

#pragma mark -
#pragma mark Pagelet Selection

- (NSRect)selectionRect
{ 
	return mySelectionRect;
}

- (void)setSelectionRect:(NSRect)aSelectionRect
{
    mySelectionRect = aSelectionRect;
}

- (NSPoint)lastClickedPoint 
{ 
	return myLastClickedPoint;
}

- (void)setLastClickedPoint:(NSPoint)aLastClickedPoint
{
    myLastClickedPoint = aLastClickedPoint;
}

- (NSMutableDictionary *)toolbars
{
    return myToolbars;
}

- (void)setToolbars:(NSMutableDictionary *)aToolbars
{
    [aToolbars retain];
    [myToolbars release];
    myToolbars = aToolbars;
}

@end


