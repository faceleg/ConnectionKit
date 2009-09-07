//
//  SVWebViewContainerView.m
//  Sandvox
//
//  Created by Mike on 04/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditingOverlay.h"
#import "SVSelectionBorder.h"
#import <QuartzCore/QuartzCore.h>   // for CoreAnimation – why isn't it pulled in by default?


@implementation SVWebEditingOverlay

- (id)initWithFrame:(NSRect)frameRect
{
    [super initWithFrame:frameRect];
    
    _selection = [[NSMutableArray alloc] init];
    
    // Create a CALayer for drawing
    CALayer *layer = [[CALayer alloc] init];
    [self setLayer:layer];
    [self setWantsLayer:YES];
    
    return self;
}

- (void)dealloc
{
    [_selection release];
    
    [super dealloc];
}

#pragma mark Basic Accessors

@synthesize dataSource = _dataSource;

#pragma mark Selection

@synthesize selectedBorders = _selection;

- (void)insertObject:(SVSelectionBorder *)border inSelectedBordersAtIndex:(NSUInteger)index;
{
    [_selection insertObject:border atIndex:index];
    [[self layer] addSublayer:border];
}

- (void)removeObjectFromSelectedBordersAtIndex:(NSUInteger)index;
{
    // Remove layer
    SVSelectionBorder *border = [_selection objectAtIndex:index];
    [border removeFromSuperlayer];
    
    [_selection removeObjectAtIndex:index];
}

#pragma mark Event Handling

- (NSView *)hitTest:(NSPoint)aPoint
{
    // Does the point correspond to one of the selections? If so, target that.
    
    
    // Otherwsie let our datasource decide.
    NSView *result = [[self dataSource] editingOverlay:self hitTest:aPoint];
    if (!result) result = [super hitTest:aPoint];
    
    return result;
}

- (void)mouseDown:(NSEvent *)theEvent
{
    
}

@end

