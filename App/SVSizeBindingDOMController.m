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

- (void)updateSize;
{
    // Workaround for #94381. Make sure any selectable parent redraws
    [[[self selectableAncestors] lastObject] setNeedsDisplay];
    
    
    
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
    [self didUpdateWithSelector:_cmd];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context == sObjectSizeObservationContext)
    {
        [self setNeedsUpdateWithSelector:@selector(updateSize)];
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark Resize

- (void)resizeToSize:(NSSize)size byMovingHandle:(SVGraphicHandle)handle;
{
    // Apply the change
    SVPlugInGraphic *graphic = [self representedObject];
    
    NSNumber *width = [NSNumber numberWithInt:size.width];
    NSNumber *height = [NSNumber numberWithInt:size.height];
    [graphic setWidth:width];
    [graphic setHeight:height];
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
