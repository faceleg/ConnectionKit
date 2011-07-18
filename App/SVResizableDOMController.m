//
//  SVResizableDOMController.m
//  Sandvox
//
//  Created by Mike on 12/08/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVResizableDOMController.h"

#import "SVGraphicContainerDOMController.h"
#import "SVPlugInGraphic.h"
#import "Sandvox.h"
#import "SVWebEditorHTMLContext.h"


static NSString *sObjectSizeObservationContext = @"SVImageSizeObservation";


@implementation SVResizableDOMController

#pragma mark Dealloc

- (void)dealloc
{
    [self setRepresentedObject:nil];
    [_width release];
    [_height release];
    [super dealloc];
}

#pragma mark DOM

- (void)loadHTMLElementFromDocument:(DOMDocument *)document;
{
    [super loadHTMLElementFromDocument:document];
    
    if ([self isHTMLElementLoaded])
    {
        DOMElement *element = [self HTMLElement];
        if (![element hasChildNodes] && ![[element tagName] isEqualToString:@"IMG"])
        {
            // Replace with placeholder
            NSString *parsedPlaceholderHTML = [[self representedObject] parsedPlaceholderHTMLFromContext:self.HTMLContext];
            [[self HTMLElement] setInnerHTML:parsedPlaceholderHTML];
        }
    }
}

- (void)setHTMLElement:(DOMHTMLElement *)element;
{
    [super setHTMLElement:element];
    
    NSNumber *width = nil;
    NSString *widthString = [element getAttribute:@"width"];
    if ([widthString length]) width = [NSNumber numberWithInteger:[widthString integerValue]];
    [_width release]; _width = [width copy];
    
    NSNumber *height = nil;
    NSString *heightString = [element getAttribute:@"height"];
    if ([heightString length]) height = [NSNumber numberWithInteger:[heightString integerValue]];
    [_height release]; _height = [height copy];
}

#pragma mark Content

@synthesize width = _width;
- (void)setWidth:(NSNumber *)width;
{
    width = [width copy];
    [_width release]; _width = width;
    
    [self setNeedsUpdateWithSelector:@selector(updateSize)];
}

@synthesize height = _height;
- (void)setHeight:(NSNumber *)height;
{
    height = [height copy];
    [_height release]; _height = height;
    
    [self setNeedsUpdateWithSelector:@selector(updateSize)];
}

- (void)setRepresentedObject:(id)object
{
    [[self representedObject] removeObserver:self forKeyPath:@"width"];
    [[self representedObject] removeObserver:self forKeyPath:@"height"];
    
    [super setRepresentedObject:object];
    
    [object addObserver:self forKeyPath:@"width" options:0 context:sObjectSizeObservationContext];
    [object addObserver:self forKeyPath:@"height" options:0 context:sObjectSizeObservationContext];
}

#pragma mark Selection

- (DOMElement *)selectableDOMElement;
{
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
    
    SVPlugInGraphic *image = [self representedObject];
    if ([image displayInline])
    {
        result = YES;
    }
    
    return result;
}

- (void)delete;
{
    // Remove parent controller instead of ourself
    SVGraphicContainerDOMController *parent = [self enclosingGraphicDOMController];
    OBASSERT(parent);
    
    [parent delete];
}

- (BOOL)shouldHighlightWhileEditing; { return YES; }

#pragma mark Updating

@synthesize sizeDelta = _delta;

- (void)updateSize;
{
    // Workaround for #94381. Make sure any selectable parent redraws
    [[[self selectableAncestors] lastObject] setNeedsDisplay];
    
    
    
    DOMHTMLElement *element = [self HTMLElement];
    [element setAttribute:@"width" value:[[self width] description]];
    [element setAttribute:@"height" value:[[self height] description]];
    
    
    
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

- (BOOL)shouldResizeInline; { return [[self representedObject] shouldWriteHTMLInline]; }

- (NSSize)minSize;
{
    SVPlugInGraphic *graphic = [self representedObject];
    
    NSSize result = NSMakeSize([graphic minWidth], [graphic minHeight]);
    if (result.width < MIN_GRAPHIC_LIVE_RESIZE) result.width = MIN_GRAPHIC_LIVE_RESIZE;
    if (result.height < MIN_GRAPHIC_LIVE_RESIZE) result.height = MIN_GRAPHIC_LIVE_RESIZE;
    
    return result;
}

- (CGFloat)maxWidth; { return [[self enclosingGraphicDOMController] maxWidth]; }

- (void)resizeToSize:(NSSize)size byMovingHandle:(SVGraphicHandle)handle;
{
    // Apply the change
    NSNumber *width = (size.width > 0 ? [NSNumber numberWithInt:size.width] : nil);
    NSNumber *height = (size.height > 0 ? [NSNumber numberWithInt:size.height] : nil);
    
    SVPlugInGraphic *graphic = [self representedObject];
    if (graphic)
    {
        [graphic setWidth:width];
        [graphic setHeight:height];
    }
    else
    {
        [self setWidth:width];
        [self setHeight:height];
    }
    
    // Push into view immediately
    [self updateIfNeeded];
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

@synthesize horizontallyResizable = _horizontallyResizable;
@synthesize verticallyResizable = _verticallyResizable;

- (unsigned int)resizingMask
{
    // TODO: Figure out how to disallow width change on inapplicable objects
    
    // Graphic's behaviour is enough to handle width, but we want height to be adjustable if requested
    unsigned int result = [[self enclosingGraphicDOMController] resizingMask];  // inline
    if (!result) result = [self resizingMaskForDOMElement:[self HTMLElement]];  // sidebar & callout
    
    if ([self isVerticallyResizable])
    {
        result = (result | kCALayerBottomEdge);
    }
    
    return result;
}

#pragma mark Layout

- (NSRect)selectionFrame;
{
    NSRect result = NSZeroRect;
    
    DOMElement *element = [self selectableDOMElement];
    if (element)
    {
        result = [element boundingBox];
        
        // Take into account padding and border
        DOMCSSStyleDeclaration *style = [[element ownerDocument] getComputedStyle:element
                                                                    pseudoElement:nil];
        
        CGFloat padding = [[style paddingLeft] floatValue];
        result.origin.x += padding;
        result.size.width -= [[style paddingRight] floatValue] + padding;
        
        padding = [[style paddingTop] floatValue];
        result.origin.y += padding;
        result.size.height -= [[style paddingBottom] floatValue] + padding;
        
        padding = [[style borderLeftWidth] floatValue];
        result.origin.x += padding;
        result.size.width -= [[style borderRightWidth] floatValue] + padding;
        
        padding = [[style borderTopWidth] floatValue];
        result.origin.y += padding;
        result.size.height -= [[style borderBottomWidth] floatValue] + padding;
    }
    
    return result;
}

@end
