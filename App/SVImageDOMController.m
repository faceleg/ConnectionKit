//
//  SVImageDOMController.m
//  Sandvox
//
//  Created by Mike on 27/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVImageDOMController.h"

#import "WebEditingKit.h"
#import "SVWebEditorHTMLContext.h"

#import "DOMNode+Karelia.h"

#import <QuartzCore/QuartzCore.h>


static NSString *sImageSizeObservationContext = @"SVImageSizeObservation";


@implementation SVImageDOMController

#pragma mark Dealloc

- (void)dealloc
{
    [self setRepresentedObject:nil];
    [super dealloc];
}

#pragma mark Element

- (NSString *)elementIdName;
{
    NSString *idName = [[self representedObject] elementIdName];
    NSString *result = (idName ? [@"image-" stringByAppendingString:idName] : nil);
    return result;
}

#pragma mark Content

- (void)setRepresentedObject:(id)image
{
    [[self representedObject] removeObserver:self forKeyPath:@"width"];
    [[self representedObject] removeObserver:self forKeyPath:@"height"];
    [[self representedObject] removeObserver:self forKeyPath:@"wrap"];
    
    [super setRepresentedObject:image];
    
    [image addObserver:self forKeyPath:@"width" options:0 context:sImageSizeObservationContext];
    [image addObserver:self forKeyPath:@"height" options:0 context:sImageSizeObservationContext];
    [image addObserver:self forKeyPath:@"wrap" options:0 context:sImageSizeObservationContext];
}

#pragma mark Selection

- (void)updateToReflectSelection;
{
    // Do nothing!!
}

- (BOOL)allowsDirectAccessToWebViewWhenSelected;
{
    /*
    if ([[self HTMLElement] isContentEditable])
    {
        return YES;
    }
    */
    return YES;//[super allowsDirectAccessToWebViewWhenSelected];
}

#pragma mark Updating

- (void)update;
{
    // mark the current area for drawing
    DOMHTMLElement *element = [self HTMLElement];
    SVImage *image = [self representedObject];
    
    BOOL liveResize = [[self webEditor] inLiveGraphicResize];
    if (!liveResize) [[element documentView] setNeedsDisplayInRect:[self drawingRect]];
    
    
    // Push property change into DOM
    SVHTMLContext *context = [[SVHTMLContext alloc] initWithOutputWriter:nil inheritFromContext:[self HTMLContext]];
    [image buildClassName:context];
    [element setClassName:[context elementClassName]];
    [context release];
    
    [element setAttribute:@"width" value:[[image width] description]];
    [element setAttribute:@"height" value:[[image height] description]];
    
    
    // and then mark the resulting area for drawing
    if (!liveResize) [[element documentView] setNeedsDisplayInRect:[self drawingRect]];
    
    
    // Finish
    [self didUpdate];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context == sImageSizeObservationContext)
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

#pragma mark Resizing

- (NSPoint)locationOfHandle:(SVGraphicHandle)handle;
{
    SVSelectionBorder *border = [self newSelectionBorder];
    
    NSPoint result = [border locationOfHandle:handle
                                    frameRect:[border frameRectForGraphicBounds:
                                               [[self HTMLElement] boundingBox]]];
    
    [border release];
    return result;
}

- (DOMElement *)graphicDOMElement; { return [self HTMLElement]; }

- (unsigned int)resizingMask
{
    // Super's behaviour is enough to handle width, but we want height to be adjustable too.
    unsigned int result = (kCALayerBottomEdge | [super resizingMask]);
    return result;
}

#define MINDIMENSION 16.0

- (NSInteger)resizeByMovingHandle:(SVGraphicHandle)handle toPoint:(NSPoint)point
{
    BOOL resizingWidth = NO;
    BOOL resizingHeight = NO;
    
    
    // Start with the original bounds.
    NSRect bounds = [[self selectableDOMElement] boundingBox];
    
    // Is the user changing the width of the graphic?
    if (handle == kSVGraphicUpperLeftHandle ||
        handle == kSVGraphicMiddleLeftHandle ||
        handle == kSVGraphicLowerLeftHandle)
    {
        // Change the left edge of the graphic.
        resizingWidth = YES;
        bounds.size.width = NSMaxX(bounds) - point.x;
        bounds.origin.x = point.x;
    }
    else if (handle == kSVGraphicUpperRightHandle ||
             handle == kSVGraphicMiddleRightHandle ||
             handle == kSVGraphicLowerRightHandle)
    {
        // Change the right edge of the graphic.
        resizingWidth = YES;
        bounds.size.width = point.x - bounds.origin.x;
    }
    
    // Did the user actually flip the graphic over?   OR RESIZE TO TOO SMALL?
    if (bounds.size.width <= MINDIMENSION) bounds.size.width = MINDIMENSION;
    
    
    
    // Is the user changing the height of the graphic?
    if (handle == kSVGraphicUpperLeftHandle ||
        handle == kSVGraphicUpperMiddleHandle ||
        handle == kSVGraphicUpperRightHandle) 
    {
        // Change the top edge of the graphic.
        resizingHeight = YES;
        bounds.size.height = NSMaxY(bounds) - point.y;
        bounds.origin.y = point.y;
    }
    else if (handle == kSVGraphicLowerLeftHandle ||
             handle == kSVGraphicLowerMiddleHandle ||
             handle == kSVGraphicLowerRightHandle)
    {
        // Change the bottom edge of the graphic.
        resizingHeight = YES;
        bounds.size.height = point.y - bounds.origin.y;
    }
    
    // Did the user actually flip the graphic upside down?   OR RESIZE TO TOO SMALL?
    if (bounds.size.height<=MINDIMENSION) bounds.size.height = MINDIMENSION;
    
    
    // Size calculated – now what to store?
    SVImage *image = [self representedObject];
	CGSize originalSize = [image originalSize];
	
#define SNAP 4
	// Snap to original size if you are very close to it
	if (resizingWidth && ( abs(bounds.size.width - originalSize.width) < SNAP) )
	{
		bounds.size.width = originalSize.width;
	}
	if (resizingHeight && ( abs(bounds.size.height - originalSize.height) < SNAP) )
	{
		bounds.size.height = originalSize.height;
	}
	
    if (resizingWidth)
    {
        if (resizingHeight)
        {
            [image setSize:bounds.size];
        }
        else
        {
            [image setWidth:[NSNumber numberWithFloat:bounds.size.width]];
        }
    }
    else if (resizingHeight)
    {
        [image setHeight:[NSNumber numberWithFloat:bounds.size.height]];
    }
    
    
    
    // The DOM has been updated, which may have caused layout. So position the mouse cursor to match
    /*point = [self locationOfHandle:handle];
    NSView *view = [[self HTMLElement] documentView];
    NSPoint basePoint = [[view window] convertBaseToScreen:[view convertPoint:point toView:nil]];
    CGWarpMouseCursorPosition(NSPointToCGPoint(basePoint));
    */
    
    return handle;
}

#pragma mark Drawing

- (SVSelectionBorder *)newSelectionBorder;
{
    SVSelectionBorder *result = [super newSelectionBorder];
    [result setBorderColor:nil];
    return result;
}

@end


#pragma mark -


@implementation SVImagePageletDOMController

- (void)awakeFromHTMLContext:(SVWebEditorHTMLContext *)context;
{
    [super awakeFromHTMLContext:context];
    
    
    // Add separate DOM controller for the image itself
    [_imageDOMController release]; _imageDOMController = [[SVImageDOMController alloc] init];
    [_imageDOMController setRepresentedObject:[self representedObject]];
    
    [self addChildWebEditorItem:_imageDOMController];
}

- (void)dealloc
{
    [_imageDOMController release];
    [super dealloc];
}

#pragma mark Controller

@synthesize imageDOMController = _imageDOMController;

- (DOMElement *)selectableDOMElement;
{
    // Normally we are, but not for chrome-less images
    DOMElement *result = ([self HTMLElement] == [[self imageDOMController] HTMLElement] ?
                          nil :
                          [super selectableDOMElement]);
    return result;
}

#pragma mark DOM

- (void)setHTMLElement:(DOMHTMLElement *)element;
{
    // Is this a change due to being orphaned while editing? If so, pass down to image controller too. #83312
    if ([self HTMLElement] == [[self imageDOMController] HTMLElement])
    {
        [[self imageDOMController] setHTMLElement:element];
    }
    
    [super setHTMLElement:element];
}

- (void)loadHTMLElementFromDocument:(DOMDocument *)document;
{
    // Hook up image controller first
    SVImageDOMController *imageController = [self imageDOMController];
    if (![imageController isHTMLElementCreated])
    {
        [imageController loadHTMLElementFromDocument:document];
    }
    
    [super loadHTMLElementFromDocument:document];
    
    // If it failed that's because the image is chromeless, so adopt its element
    if (![self isHTMLElementCreated])
    {
        [self setHTMLElement:[imageController HTMLElement]];
    }
}

@end


#pragma mark -


@implementation SVImage (SVDOMController)

- (SVDOMController *)newDOMController;
{
    //Class class = ([self isPagelet] ? [SVImagePageletDOMController class] : [SVImageDOMController class]);
    return [[SVImagePageletDOMController alloc] initWithRepresentedObject:self];
}

@end

