//
//  SVSizeBindingDOMController.m
//  Sandvox
//
//  Created by Mike on 12/08/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVSizeBindingDOMController.h"

#import "SVGraphicDOMController.h"
#import "SVPageletPlugIn.h"


static NSString *sObjectSizeObservationContext = @"SVImageSizeObservation";


@implementation SVSizeBindingDOMController

#pragma mark Dealloc

- (void)dealloc
{
    [self setRepresentedObject:nil];
    [super dealloc];
}

#pragma mark Content

- (void)setRepresentedObject:(id)object
{
    [[self representedObject] removeObserver:self forKeyPath:@"width"];
    [[self representedObject] removeObserver:self forKeyPath:@"height"];
    
    [super setRepresentedObject:object];
    
    [object addObserver:self forKeyPath:@"width" options:0 context:sObjectSizeObservationContext];
    [object addObserver:self forKeyPath:@"height" options:0 context:sObjectSizeObservationContext];
}

#pragma mark Selection

- (BOOL)tryToRemove;
{
    // Remove parent controller instead of ourself
    WEKWebEditorItem *parent = [self parentWebEditorItem];
    OBASSERT([parent isKindOfClass:[SVGraphicDOMController class]]);
    
    return [parent tryToRemove];
}

#pragma mark Updating

- (void)update;
{
    // mark the current area for drawing
    DOMHTMLElement *element = [self HTMLElement];
    NSObject *object = [self representedObject];
    
    
    // Push size change into DOM
    [element setAttribute:@"width" value:[[object valueForKey:@"width"] description]];
    [element setAttribute:@"height" value:[[object valueForKey:@"height"] description]];
    
    
    // Finish
    [self didUpdate];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context == sObjectSizeObservationContext)
    {
        if ([[self webEditor] inLiveGraphicResize])
        {
            [self update];
        }
        else
        {
            [self setNeedsUpdate];
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end


#pragma mark -


// Plug-ins don't implement this stuff, so we're going to have to fake it for now.

@interface SVPlugIn (SVSizeBindingDOMController) //<SVDOMControllerRepresentedObject>
@end

@implementation SVPlugIn (SVSizeBindingDOMController)

- (NSString *)elementIdName; { return nil; }

- (BOOL)shouldPublishEditingElementID; { return NO; }

@end
