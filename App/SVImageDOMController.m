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

#import "DOMNode+Karelia.h"

#import <QuartzCore/QuartzCore.h>


@implementation SVImageDOMController

#pragma mark Creation

- (void)awakeFromHTMLContext:(SVWebEditorHTMLContext *)context;
{
    [super awakeFromHTMLContext:context];
    
    SVMediaGraphicDOMController *parent = (SVMediaGraphicDOMController *)[self parentWebEditorItem];
    OBASSERT([parent isKindOfClass:[SVMediaGraphicDOMController class]]);
    [parent setImageDOMController:self];
}

#pragma mark Element

- (NSString *)elementIdName;
{
    NSString *idName = [[self representedObject] elementIdName];
    NSString *result = (idName ? [@"image-" stringByAppendingString:idName] : nil);
    return result;
}

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
    SVMediaGraphic *image = [self representedObject];
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
    return [(SVMediaGraphicDOMController *)[self parentWebEditorItem] constrainSize:size handle:handle];
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

- (SVSelectionBorder *)newSelectionBorder;
{
    SVSelectionBorder *result = [super newSelectionBorder];
    [result setBorderColor:nil];
    return result;
}

@end

