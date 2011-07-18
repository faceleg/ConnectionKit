//
//  SVMediaDOMController.m
//  Sandvox
//
//  Created by Mike on 18/10/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVMediaDOMController.h"

#import "SVPasteboardItemInternal.h"
#import "SVTextAttachment.h"

#import "NSColor+Karelia.h"


@implementation SVMediaDOMController

#pragma mark Selection

- (DOMElement *)selectableDOMElement;
{
    // Media is always selectable. #102520
    return [self HTMLElement];
}

- (DOMRange *)selectableDOMRange;
{
    if ([self shouldTrySelectingInline])
    {
        DOMElement *element = [self selectableDOMElement];
        DOMRange *result = [[element ownerDocument] createRange];
        [result selectNode:element];
        return result;
    }
    else
    {
        return [super selectableDOMRange];
    }
}

- (BOOL)allowsDirectAccessToWebViewWhenSelected;
{
    // Generally, no. EXCEPT for inline, non-wrap-causing images
    BOOL result = NO;
    
    SVMediaGraphic *image = [self representedObject];
    if ([image displayInline])
    {
        result = YES;
    }
    
    return result;
}

#pragma mark Resize

- (NSSize)minSize;
{
    // Remove the 200px width restriction
    NSSize result = [super minSize];
    result.width = result.height;
    return result;
}

#pragma mark Drawing

- (void)updateToReflectSelection;
{
    // Do nothing!!
}

@end


#pragma mark -


@implementation SVMediaContainerDOMController

#pragma mark DOM

- (void)setHTMLElement:(DOMHTMLElement *)element;
{
    // Is this a change due to being orphaned while editing? If so, pass down to image controller too. #83312
    for (WEKWebEditorItem *anItem in [self childWebEditorItems])
    {
        if ([self isHTMLElementLoaded] && ([self HTMLElement] == [anItem HTMLElement]))
        {
            [anItem setHTMLElement:element];
        }
    }
    
    
    [super setHTMLElement:element];
}

#pragma mark Update

- (void)updateSize;
{
    if ([[self selectableTopLevelDescendants] count] > 1)	// #93182
    {
        [super updateSize];
    }
    else
    {
        [self didUpdateWithSelector:_cmd];   // fake it
    }
}

#pragma mark Resizing

- (NSSize)constrainSize:(NSSize)size handle:(SVGraphicHandle)handle snapToFit:(BOOL)snapToFit;
{
    size = [super constrainSize:size handle:handle snapToFit:snapToFit];
    
    
    if (snapToFit)
    {
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
        
        SVMediaPlugIn *plugIn = [(SVMediaGraphic *)[self representedObject] plugIn];
        NSNumber *naturalWidth = [plugIn naturalWidth];
        NSNumber *naturalHeight = [plugIn naturalHeight];
         
        
        // Snap if we are near the original size.
        if (naturalWidth && naturalHeight)
        {
            int snap = MIN([naturalWidth floatValue]/4, 10);	// snap to smaller of 25% image width or 10 pixels
            if (resizingWidth && ( abs(size.width - [naturalWidth floatValue]) < snap) )
            {
                size.width = [naturalWidth floatValue];
            }
            if (resizingHeight && ( abs(size.height - [naturalHeight floatValue]) < snap) )
            {
                size.height = [naturalHeight floatValue];
            }
        }
    }
    
    
    return size;
}

@end
