//
//  SVImageDOMController.m
//  Sandvox
//
//  Created by Mike on 27/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVImageDOMController.h"

#import "WebEditingKit.h"
#import "SVGraphicFactory.h"
#import "SVWebEditorHTMLContext.h"

#import "NSColor+Karelia.h"
#import "DOMNode+Karelia.h"

#import <QuartzCore/QuartzCore.h>


@implementation SVImageDOMController

#pragma mark Creation

- (void)awakeFromHTMLContext:(SVWebEditorHTMLContext *)context;
{
    [super awakeFromHTMLContext:context];
    
    SVImagePageletDOMController *parent = (SVImagePageletDOMController *)[self parentWebEditorItem];
    OBASSERT([parent isKindOfClass:[SVImagePageletDOMController class]]);
    [parent setImageDOMController:self];
}

#pragma mark Element

- (NSString *)elementIdName;
{
    NSString *idName = [[self representedObject] elementIdName];
    NSString *result = (idName ? [@"image-" stringByAppendingString:idName] : nil);
    return result;
}

#pragma mark Properties

// TODO: proper logic for this:
- (BOOL)isMediaPlaceholder; { return YES; }

#pragma mark Selection

- (void)updateToReflectSelection;
{
    // Do nothing!!
}

- (BOOL)allowsDirectAccessToWebViewWhenSelected;
{
    // Generally, yes. EXCEPT for inline, block-level, chromeless images
    BOOL result = YES;
    
    if (![[self parentWebEditorItem] isSelectable])
    {
        SVImage *image = [self representedObject];
        if (![image shouldWriteHTMLInline])
        {
            result = NO;
        }
    }
    
    return result;
}

#pragma mark Resizing

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
    SVImage *image = [self representedObject];
	if (resizingWidth)
    {
        if (resizingHeight)
        {
            [image setSize:size];
        }
        else
        {
            [image setWidth:[NSNumber numberWithFloat:size.width]];
        }
    }
    else if (resizingHeight)
    {
        [image setHeight:[NSNumber numberWithFloat:size.height]];
    }
}

- (NSSize)constrainSize:(NSSize)size handle:(SVGraphicHandle)handle;
{
    // Image lives inside a graphic DOM controller, so use the size limit from that instead
    return [(SVImagePageletDOMController *)[self parentWebEditorItem] constrainSize:size handle:handle];
}

- (NSSize)minSize;
{
    // Remove the 200px width restriction
    NSSize result = [super minSize];
    result.width = result.height;
    return result;
}

- (NSPoint)locationOfHandle:(SVGraphicHandle)handle;
{
    SVSelectionBorder *border = [self newSelectionBorder];
    
    NSPoint result = [border locationOfHandle:handle
                                    frameRect:[border frameRectForGraphicBounds:
                                               [[self HTMLElement] boundingBox]]];
    
    [border release];
    return result;
}

- (DOMElement *)selectableDOMElement; { return [self HTMLElement]; }

- (unsigned int)resizingMask
{
    // Super's behaviour is enough to handle width, but we want height to be adjustable too.
    unsigned int result = (kCALayerBottomEdge | [super resizingMask]);
    return result;
}

#define MINDIMENSION 16.0

#pragma mark Drawing

- (NSRect)drawingRect;
{
    NSRect result = [super drawingRect];
    
    if (_drawAsDropTarget)
    {
        result = NSUnionRect(result, [[self HTMLElement] boundingBox]);
    }
    
    return result;
}

- (void)drawRect:(NSRect)dirtyRect inView:(NSView *)view;
{
    [super drawRect:dirtyRect inView:view];
    
    // Draw outline
    if (_drawAsDropTarget)
    {
        [[NSColor aquaColor] set];
        NSFrameRectWithWidth([[self HTMLElement] boundingBox], 2.0f);
    }
}

- (SVSelectionBorder *)newSelectionBorder;
{
    SVSelectionBorder *result = [super newSelectionBorder];
    [result setBorderColor:nil];
    return result;
}

#pragma mark Drag & Drop

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;
{
    if ([self isMediaPlaceholder])
    {
        _drawAsDropTarget = YES;
        [self setNeedsDisplay];
        return NSDragOperationCopy;
    }
    
    return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender;
{
    [self setNeedsDisplay];
    _drawAsDropTarget = NO;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;
{
    NSPasteboard *pboard = [sender draggingPasteboard];
    
    SVGraphicFactory *factory = [SVGraphicFactory mediaPlaceholderFactory];
    NSString *type = [pboard availableTypeFromArray:[factory readablePasteboardTypes]];
    if (type)
    {
        
    }
    
    return NO;
}

- (NSArray *)registeredDraggedTypes;
{
    return [[SVGraphicFactory mediaPlaceholderFactory] readablePasteboardTypes];
}

@end


#pragma mark -


@implementation SVImagePageletDOMController

- (SVSizeBindingDOMController *)newSizeBindingControllerWithRepresentedObject:(id)object;
{
    return [[SVImageDOMController alloc] initWithRepresentedObject:object];
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
    DOMElement *imageElement = [[self imageDOMController] HTMLElement];
    DOMElement *result = [super selectableDOMElement];
    
    if (result == imageElement) result = nil;
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

#pragma mark Resizing

- (NSSize)constrainSize:(NSSize)size handle:(SVGraphicHandle)handle;
{
    size = [super constrainSize:size handle:handle];
    
    
    // Snap to original size if you are very close to it
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
    
    SVImage *image = [self representedObject];
	CGSize originalSize = [image originalSize];
	
#define SNAP 4
	if (resizingWidth && ( abs(size.width - originalSize.width) < SNAP) )
	{
		size.width = originalSize.width;
	}
	if (resizingHeight && ( abs(size.height - originalSize.height) < SNAP) )
	{
		size.height = originalSize.height;
	}
    
    
    return size;
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

