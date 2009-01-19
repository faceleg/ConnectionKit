//
//  KTDraggingInfo.m
//  KTComponents
//
//  Created by Terrence Talbot on 10/20/04.
//  Copyright 2004-2009 Karelia Software. All rights reserved.
//

#import "KTDraggingInfo.h"

#import "Debug.h"


@implementation KTDraggingInfo

+ (KTDraggingInfo *)draggingInfoWithDraggingInfo:(id <NSDraggingInfo>)info
{
    KTDraggingInfo *newInfo = [[[self alloc] init] autorelease];
    
    [newInfo setDraggedImage:[info draggedImage]];
    [newInfo setDraggedImageLocation:[info draggedImageLocation]];
    [newInfo setDraggingDestinationWindow:[info draggingDestinationWindow]];
    [newInfo setDraggingLocation:[info draggingLocation]];
    [newInfo setDraggingPasteboard:[info draggingPasteboard]];
    [newInfo setDraggingSequenceNumber:[info draggingSequenceNumber]];
    [newInfo setDraggingSource:[info draggingSource]];
    [newInfo setDraggingSourceOperationMask:[info draggingSourceOperationMask]];
    
    return newInfo;
}

+ (KTDraggingInfo *)draggingInfoWithDraggingInfo:(id <NSDraggingInfo>)info pbaord:(NSPasteboard *)aPboard
{
    KTDraggingInfo *newInfo = [self draggingInfoWithDraggingInfo:info];
    [newInfo setDraggingPasteboard:aPboard];
    
    return newInfo;
}


- (void)setDraggedImage:(NSImage *)anImage
{
    [anImage retain];
    [myDraggedImage release];
    myDraggedImage = anImage;
}

- (NSImage *)draggedImage
{
    return myDraggedImage;
}

- (void)setDraggedImageLocation:(NSPoint)aLocation
{
    myDraggedImageLocation = aLocation;
}

- (NSPoint)draggedImageLocation
{
    return myDraggedImageLocation;
}

- (void)setDraggingDestinationWindow:(NSWindow *)aWindow
{
    [aWindow retain];
    [myDraggingDestinationWindow release];
    myDraggingDestinationWindow = aWindow;
}

- (NSWindow *)draggingDestinationWindow
{
    return myDraggingDestinationWindow;
}

- (void)setDraggingLocation:(NSPoint)aLocation
{
    myDraggingLocation = aLocation;
}

- (NSPoint)draggingLocation
{
    return myDraggingLocation;
}

- (void)setDraggingPasteboard:(NSPasteboard *)aPboard
{
    [aPboard retain];
    [myDraggingPasteboard release];
    myDraggingPasteboard = aPboard;
}

- (NSPasteboard *)draggingPasteboard
{
    return myDraggingPasteboard;
}

- (void)setDraggingSequenceNumber:(int)anInt
{
    myDraggingSequenceNumber = anInt;
}

- (int)draggingSequenceNumber
{
    return myDraggingSequenceNumber;
}

- (void)setDraggingSource:(id)anObject
{
    [anObject retain];
    [myDraggingSource release];
    myDraggingSource = anObject;
}

- (id)draggingSource
{
    return myDraggingSource;
}

- (void)setDraggingSourceOperationMask:(NSDragOperation)anOperationMask
{
    myDraggingSourceOperationMask = anOperationMask;
}

- (NSDragOperation)draggingSourceOperationMask
{
    return myDraggingSourceOperationMask;
}

- (NSArray *)namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination
{
    LOG((@"KTDraggingInfo asked namesOfPromisedFilesDroppedAtDestination:, return nil."));
    return nil;
}

- (void)slideDraggedImageTo:(NSPoint)aPoint
{
    LOG((@"KTDraggingInfo asked slideDraggedImageTo:, doing nothing."));
}

		
@end
