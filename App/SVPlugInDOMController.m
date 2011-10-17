//
//  SVPlugInDOMController.m
//  Sandvox
//
//  Created by Mike on 12/08/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVPlugInDOMController.h"

#import "SVGraphicContainerDOMController.h"
#import "SVPlugInGraphic.h"
#import "Sandvox.h"
#import "SVWebEditorHTMLContext.h"


@implementation SVPlugInDOMController

#pragma mark Selection

- (BOOL)allowsDirectAccessToWebViewWhenSelected;
{
    // Generally, no. EXCEPT for inline, non-wrap-causing images
    BOOL result = NO;
    
    SVPlugInGraphic *image = [self representedObject];
    if ([image displayInline])
    {
        result = YES;
    }
    
    return result;
}

- (BOOL)shouldHighlightWhileEditing; { return YES; }

#pragma mark Resize

- (BOOL)shouldResizeInline; { return [[self representedObject] shouldWriteHTMLInline]; }

- (NSSize)minSize;
{
    SVPlugInGraphic *graphic = [self representedObject];
    
    NSSize result = NSMakeSize([graphic minWidth], [graphic minHeight]);
    if (result.width < MIN_GRAPHIC_LIVE_RESIZE) result.width = MIN_GRAPHIC_LIVE_RESIZE;
    if (result.height < MIN_GRAPHIC_LIVE_RESIZE) result.height = MIN_GRAPHIC_LIVE_RESIZE;
    
    return result;
}

- (NSSize)constrainSize:(NSSize)size handle:(SVGraphicHandle)handle snapToFit:(BOOL)snapToFit;
{
    /*  This logic is almost identical to SVGraphicDOMController, although the code there can probably be pared down to deal only with width
     */
    
    
    
    // Take into account padding
    SVGraphic *graphic = [self representedObject];
    
    NSNumber *widthPadding = [graphic elementWidthPadding];
    if (widthPadding) size.width -= [widthPadding floatValue];
    
    NSNumber *heightPadding = [graphic elementHeightPadding];
    if (heightPadding) size.height -= [heightPadding floatValue];
    
    
    
    // Disregard height if requested
    if (![self isVerticallyResizable])
    {
        size.height = [[graphic height] unsignedIntegerValue];
    }
    
    
    
    // If constrained proportions, apply that. Have to enforce min sizes too
    NSNumber *ratio = [graphic constrainedProportionsRatio];
    NSUInteger minWidth = [graphic minWidth];
        
    if (ratio)
    {
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
        
        if (resizingWidth)
        {
            // Enforce min width
            if (size.width < minWidth) size.width = minWidth;
            
            if (resizingHeight)
            {
                // Go for the biggest size of the two possibilities
                CGFloat unconstrainedRatio = size.width / size.height;
                if (fabs(unconstrainedRatio) < [ratio floatValue])
                {
                    size.width = size.height * [ratio floatValue];
                }
                else
                {
                    size.height = size.width / [ratio floatValue];
                }
            }
            else
            {
                size.height = size.width / [ratio floatValue];
            }
        }
        else
        {
            size.width = size.height * [ratio floatValue];
            
            // Is this too low? If so, bump size back up. #94988
            NSUInteger minWidthForGraphic = [graphic minWidth];
            if (size.width < minWidthForGraphic)
            {
                size.width = minWidthForGraphic;
                size.height = size.width / [ratio floatValue];
            }
        }
    }
    
    
    
    if (snapToFit)
    {
        // Keep within max width/height
        CGFloat maxWidth = [self maxWidth];
        NSNumber *maxHeight = [graphic maxHeight];
        
        if (size.width > maxWidth)
        {
            if ([graphic isExplicitlySized])
            {
                size.width = maxWidth;
            }
            else
            {
                // Switch over to auto-sized for simple graphics.
                // Exception to this if it auto-width would actually be smaller. e.g. audio defaults to 200px wide. #102520
                size.width = 0.0f;
                
                DOMElement *element = [self HTMLElement];
                DOMCSSRuleList *rules = [[element ownerDocument] getMatchedCSSRules:element pseudoElement:nil authorOnly:NO];
                DOMCSSRule *aRule = [rules item:0];
                
                if ([aRule isKindOfClass:[DOMCSSStyleRule class]])
                {
                    DOMCSSStyleDeclaration *style = [(DOMCSSStyleRule *)aRule style];
                    NSString *defaultWidth = [style width];
                    if ([defaultWidth hasSuffix:@"px"] && [defaultWidth integerValue] < maxWidth)
                    {
                        size.width = maxWidth;
                    }
                }
            }
            
            if (ratio) size.height = maxWidth / [ratio floatValue];
        }
        
        if (maxHeight && size.height > [maxHeight floatValue])
        {
            size.height = [maxHeight floatValue];
            if (ratio) size.width = size.height * [ratio floatValue];
        }
    }
    
    
    return size;
}

- (unsigned int)resizingMask
{
    // TODO: Figure out how to disallow width change on inapplicable objects
    
    // Graphic's behaviour is enough to handle width, but we want height to be adjustable if requested
    unsigned int result = [[self enclosingGraphicDOMController] resizingMask];  // inline
    if (!result) result = [self resizingMaskForDOMElement:[self HTMLElement]];  // sidebar & callout
    
    result = (result | [super resizingMask]);
    
    return result;
}

@end
