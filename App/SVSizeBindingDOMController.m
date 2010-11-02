//
//  SVSizeBindingDOMController.m
//  Sandvox
//
//  Created by Mike on 12/08/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVSizeBindingDOMController.h"

#import "SVGraphicDOMController.h"
#import "SVPlugInGraphic.h"
#import "SVPlugIn.h"
#import "SVWebEditorHTMLContext.h"


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

- (DOMElement *) selectableDOMElement; { return [self HTMLElement]; }

- (BOOL)tryToRemove;
{
    // Remove parent controller instead of ourself
    WEKWebEditorItem *parent = [self parentWebEditorItem];
    OBASSERT([parent isKindOfClass:[SVGraphicDOMController class]]);
    
    return [parent tryToRemove];
}

#pragma mark Updating

@synthesize sizeDelta = _delta;

- (void)update;
{
    // mark the current area for drawing
    DOMHTMLElement *element = [self HTMLElement];
    NSObject *object = [self representedObject];
    
    
    // Push size change into DOM
    SVHTMLContext *context = [[SVHTMLContext alloc] initWithOutputWriter:nil
                                                      inheritFromContext:[self HTMLContext]];
    
    [context buildAttributesForElement:[[element tagName] lowercaseString]
                      bindSizeToObject:object
                    DOMControllerClass:[self class]
							 sizeDelta:[self sizeDelta]];			// Need something dynamic here?
    
    NSDictionary *attributes = [context elementAttributes];
    [element setAttribute:@"width" value:[attributes objectForKey:@"width"]];
    [element setAttribute:@"height" value:[attributes objectForKey:@"height"]];
    [element setAttribute:@"style" value:[attributes objectForKey:@"style"]];
    
    [context release];
    
    
    
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

#pragma mark Resize

- (void)resizeToSize:(NSSize)size byMovingHandle:(SVGraphicHandle)handle;
{
    // Size calculated – now what to store?
    BOOL resizingWidth = (handle == kSVGraphicUpperLeftHandle ||
                          handle == kSVGraphicMiddleLeftHandle ||
                          handle == kSVGraphicLowerLeftHandle ||
                          handle == kSVGraphicUpperRightHandle ||
                          handle == kSVGraphicMiddleRightHandle ||
                          handle == kSVGraphicLowerRightHandle);
    
    BOOL resizingHeight = (handle == kSVGraphicUpperLeftHandle ||
                           handle == kSVGraphicUpperMiddleHandle ||
                           handle == kSVGraphicUpperRightHandle ||
                           handle == kSVGraphicLowerLeftHandle ||
                           handle == kSVGraphicLowerMiddleHandle ||
                           handle == kSVGraphicLowerRightHandle);
    
    
    // Apply the change
    SVPlugInGraphic *graphic = [self representedObject];
	if (resizingWidth)
    {
        if (resizingHeight)
        {
            [graphic setSize:size];
        }
        else
        {
            [graphic setWidth:[NSNumber numberWithFloat:size.width]];
        }
    }
    else if (resizingHeight)
    {
        [graphic setHeight:[NSNumber numberWithFloat:size.height]];
    }
}

- (NSSize)constrainSize:(NSSize)size handle:(SVGraphicHandle)handle snapToFit:(BOOL)snapToFit;
{
    // Graphic lives inside a body DOM controller, so use the size limit from that instead
    return [(SVDOMController *)[self parentWebEditorItem] constrainSize:size handle:handle snapToFit:snapToFit];
}

- (unsigned int)resizingMask
{
    // Super's behaviour is enough to handle width, but we want height to be adjustable 
    // TODO: Figure out how to disallow width change on inapplicable objects
    unsigned int result = (kCALayerBottomEdge | [super resizingMask]);
    return result;
}

@end


#pragma mark -


// Plug-ins don't implement this stuff, so we're going to have to fake it for now.

@interface SVPlugIn (SVSizeBindingDOMController) //<SVDOMControllerRepresentedObject>
@end

@implementation SVPlugIn (SVSizeBindingDOMController)

- (BOOL)shouldPublishEditingElementID; { return NO; }

@end
