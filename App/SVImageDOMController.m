//
//  SVImageDOMController.m
//  Sandvox
//
//  Created by Mike on 27/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVImageDOMController.h"

#import <QuartzCore/QuartzCore.h>


static NSString *sImageSizeObservationContext = @"SVImageSizeObservation";


@implementation SVImageDOMController

- (void)dealloc
{
    [self setRepresentedObject:nil];
    [super dealloc];
}

- (void)setRepresentedObject:(id)image
{
    [[self representedObject] removeObserver:self forKeyPath:@"width"];
    [[self representedObject] removeObserver:self forKeyPath:@"height"];
    
    [super setRepresentedObject:image];
    
    [image addObserver:self forKeyPath:@"width" options:0 context:sImageSizeObservationContext];
    [image addObserver:self forKeyPath:@"height" options:0 context:sImageSizeObservationContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context == sImageSizeObservationContext)
    {
        [[self HTMLElement] setAttribute:keyPath
                                   value:[[object valueForKeyPath:keyPath] description]];
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (unsigned int)resizingMask
{
    return kCALayerRightEdge | kCALayerBottomEdge;
}

- (NSInteger)resizeByMovingHandle:(SVGraphicHandle)handle toPoint:(NSPoint)point
{
    BOOL resizingWidth = NO;
    BOOL resizingHeight = NO;
    
    
    // Start with the original bounds.
    NSRect bounds = [[self HTMLElement] boundingBox];
    
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
    
    // Did the user actually flip the graphic over?
    if (bounds.size.width <= 0.0f) bounds.size.width = 1.0f;
    
    
    
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
    
    // Did the user actually flip the graphic upside down?
    if (bounds.size.height<=0.0f) bounds.size.height = 1.0f;
    
    
    // Size calculated – now what to store?
    SVImage *image = [self representedObject];
    if (resizingWidth)
    {
        if (resizingHeight)
        {
            if ([[image constrainProportions] boolValue])
            {
                // TODO: better logic
                [image setWidth:[NSNumber numberWithFloat:bounds.size.width]];
            }
            else
            {
                [image setWidth:[NSNumber numberWithFloat:bounds.size.width]];
                [image setHeight:[NSNumber numberWithFloat:bounds.size.height]];
            }
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
    
    
    
    return handle;
}

@end
