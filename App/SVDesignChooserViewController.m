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
}

@synthesize designs = designs_;
@synthesize designsArrayController = oArrayController;
@synthesize designsCollectionView = oCollectionView;
@end

@implementation SVDesignChooserScrollView

- (void)awakeFromNib
{
    NSColor *startingColor = [NSColor darkGrayColor];
    NSColor *endingColor = [NSColor blackColor];
    backgroundGradient_ = [[NSGradient alloc] initWithStartingColor:startingColor
                                                        endingColor:endingColor];    
}

- (void)drawRect:(NSRect)rect
{
    [backgroundGradient_ drawInRect:[self bounds] angle:90.0];
}

- (void)dealloc
{
    [backgroundGradient_ release];
    [super dealloc];
}

@end

@implementation SVDesignChooserViewBox

- (void)awakeFromNib
{
    // here's a little tip: boxType must be Custom and borderType must be Line
    //[self setFillColor:[NSColor selectedControlColor]];
    [self setFillColor:[NSColor alternateSelectedControlColor]];
}

- (NSView *)hitTest:(NSPoint)aPoint
{
    return nil; // don't allow any mouse clicks for subviews
}

@end
