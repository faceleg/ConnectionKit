//
//  SVIndexDOMController.m
//  Sandvox
//
//  Created by Mike on 19/10/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVIndexDOMController.h"

#import "SVGraphicFactory.h"
#import "SVPlugInGraphic.h"
#import "SVPagesController.h"


@implementation SVIndexDOMController

- (void)setRepresentedObject:(id)object;
{
    [super setRepresentedObject:object];
    
    // We'll take basically anything, since that avoids having to load all plug-ins
    [self unregisterDraggedTypes];
    [self registerForDraggedTypes:NSARRAY((NSString *)kUTTypeItem,
                                          NSFilenamesPboardType)];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;
{
    // Add pages to the collection, corresponding to media
    id <SVPage> collection = [(SVIndexPlugIn *)[[self representedObject] plugIn] indexedCollection];
    
    SVPagesController *controller = [SVPagesController controllerWithPagesInCollection:collection bind:YES];
    
    BOOL result = [controller addObjectsFromPasteboard:[sender draggingPasteboard]];
    return result;
}

@end


#pragma mark -


@implementation SVPlugInGraphic (SVIndexDOMController)

- (SVDOMController *)newBodyDOMController;
{
    if ([[self plugIn] isKindOfClass:[SVIndexPlugIn class]])
    {
        return [[SVIndexDOMController alloc] initWithRepresentedObject:self];
    }
    
    return [super newBodyDOMController];
}

@end

