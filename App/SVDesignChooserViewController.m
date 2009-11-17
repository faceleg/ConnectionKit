//
//  SVDesignChooserViewController.m
//  Sandvox
//
//  Created by Terrence Talbot on 8/28/09.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVDesignChooserViewController.h"

#import "KSPlugin.h"
#import "KT.h"


@implementation SVDesignChooserViewController

- (void)awakeFromNib
{
    // load designs -- only seems to work if I do it here? seems as good a place as any...
    [self setDesigns:[KSPlugin sortedPluginsWithFileExtension:kKTDesignExtension]];
    
    // restrict to a max of 4 columns
    [oCollectionView setMaxNumberOfColumns:4];
}

@synthesize designs = designs_;
@synthesize designsArrayController = oArrayController;
@synthesize designsCollectionView = oCollectionView;
@end

@implementation SVDesignChooserScrollView

- (void)awakeFromNib
{
    //NSColor *startingColor = [NSColor darkGrayColor];
    //NSColor *endingColor = [NSColor blackColor];
    //backgroundGradient_ = [[NSGradient alloc] initWithStartingColor:startingColor
    //                                                    endingColor:endingColor];    
}

- (void)drawRect:(NSRect)rect
{
    //[backgroundGradient_ drawInRect:[self bounds] angle:90.0];
    //[[NSColor colorWithCalibratedRed:0.079 green:0.079 blue:0.079 alpha:1.000] set];
    //[NSBezierPath fillRect:rect];
}

- (void)dealloc
{
    //[backgroundGradient_ release];
    [super dealloc];
}

@end

@implementation SVDesignChooserViewBox

- (NSView *)hitTest:(NSPoint)aPoint
{
    return nil; // don't allow any mouse clicks for subviews (needed?)
}

@end

@implementation SVDesignChooserSelectionView


// view's hidden binding is bound to viewcontoller.selection (NSNegateBoolean)
// so this only appears drawn around the selection
- (void)drawRect:(NSRect)rect
{
	// draw a rectangle under where the highlight will go
    NSBezierPath *underPath = [NSBezierPath bezierPathWithRect:rect];
    [underPath setLineWidth:3.0];
    [underPath setLineJoinStyle:NSRoundLineJoinStyle];
    [[NSColor colorWithCalibratedWhite:0.10 alpha:1.0] set];
    [underPath stroke];
	
    // do a thicker line in selectedControlColor to indicate selection
    NSBezierPath *highlightPath = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(rect, 1.5, 1.5) xRadius:9.0 yRadius:9.0];
    [highlightPath setLineWidth:3.0];
    [highlightPath setLineJoinStyle:NSRoundLineJoinStyle];
    [[NSColor alternateSelectedControlColor] set];
    [highlightPath stroke];
}

@end
