//
//  SVSizeBindingDOMController.m
//  Sandvox
//
//  Created by Mike on 12/08/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
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

- (DOMElement *) selectableDOMElement;
{
    // Can be selected if graphic is explictly sized
    SVPlugInGraphic *graphic = [self representedObject];
    return ([graphic isExplicitlySized] ? [self HTMLElement] : nil);
}

- (void)delete;
{
    // Remove parent controller instead of ourself
    SVGraphicDOMController *parent = [self enclosingGraphicDOMController];
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
    
    NSObject *object = [self representedObject];
    if ([object isKindOfClass:[SVPlugInGraphic class]]) object = [(SVPlugInGraphic *)object plugIn];
    
    
    // Push size change into DOM
    SVHTMLContext *context = [[SVHTMLContext alloc] initWithOutputWriter:nil
                                                      inheritFromContext:[self HTMLContext]];
    
    [context buildAttributesForElement:[[element tagName] lowercaseString]
                      bindSizeToObject:object
                    DOMControllerClass:[self class]
							 sizeDelta:[self sizeDelta]];			// Need something dynamic here?
    
    NSDictionary *attributes = [[context currentElementInfo] attributesAsDictionary];
    [element setAttribute:@"width" value:[attributes objectForKey:@"width"]];
    [element setAttribute:@"height" value:[attributes objectForKey:@"height"]];
    [element setAttribute:@"style" value:[attributes objectForKey:@"style"]];
    
    [context close];
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

- (BOOL)shouldResizeInline; { return YES; }

- (CGFloat)maxWidth; { return [[self enclosingGraphicDOMController] maxWidth]; }

- (void)resizeToSize:(NSSize)size byMovingHandle:(SVGraphicHandle)handle;
{
    // Apply the change
    SVPlugInGraphic *graphic = [self representedObject];
    
    NSNumber *width = [NSNumber numberWithInt:size.width];
    NSNumber *height = [NSNumber numberWithInt:size.height];
    [graphic setWidth:width];
    [graphic setHeight:height];
    
    // Push into view immediately
    [self updateIfNeeded];
}

- (NSSize)constrainSize:(NSSize)size handle:(SVGraphicHandle)handle snapToFit:(BOOL)snapToFit;
{
    /*  This logic is almost identical to SVGraphicDOMController, although the code there can probably be pared down to deal only with width
     */
    
    
    
    // Take into account padding
    SVPlugInGraphic *graphic = [self representedObject];
    
    NSNumber *widthPadding = [[graphic plugIn] elementWidthPadding];
    if (widthPadding) size.width -= [widthPadding floatValue];
    
    NSNumber *heightPadding = [[graphic plugIn] elementHeightPadding];
    if (heightPadding) size.height -= [heightPadding floatValue];
    
    
    
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
        CGFloat maxWidth = [self maxWidth];
        if (size.width > maxWidth)
        {
            // Keep within max width
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
    }
    
    
    return size;
}

- (unsigned int)resizingMask
{
    // TODO: Figure out how to disallow width change on inapplicable objects
    
    // Graphic's behaviour is enough to handle width, but we want height to be adjustable if requested
    unsigned int result = [[self enclosingGraphicDOMController] resizingMask];  // inline
    if (!result) result = [self resizingMaskForDOMElement:[self HTMLElement]];  // sidebar & callout
    
    SVPlugInGraphic *graphic = [self representedObject];
    if ([graphic isExplicitlySized]) result = (result | kCALayerBottomEdge);
    
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


#pragma mark -


// Plug-ins don't implement this stuff, so we're going to have to fake it for now.

@interface SVPlugIn (SVSizeBindingDOMController) //<SVDOMControllerRepresentedObject>
@end

@implementation SVPlugIn (SVSizeBindingDOMController)

- (BOOL)shouldPublishEditingElementID; { return NO; }

@end
