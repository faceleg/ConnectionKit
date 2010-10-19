//
//  SVIndexDOMController.m
//  Sandvox
//
//  Created by Mike on 19/10/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVIndexDOMController.h"

#import "SVGraphicFactory.h"


@implementation SVIndexDOMController

- (NSArray *)registeredDraggedTypes
{
    return [SVGraphicFactory graphicPasteboardTypes];
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;
{
    return NSDragOperationCopy;
}

@end
