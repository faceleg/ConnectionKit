//
//  SVInspectorButton.m
//  Sandvox
//
//  Created by Mike on 16/11/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "SVInspectorButtonCell.h"

#import "KSInspectorTabCell.h"


@implementation SVInspectorButtonCell

- (NSInteger)nextState
{
    return NSOnState;
}

- (void) drawBezelWithFrame:(NSRect)frame inView:(NSView *)controlView;
{
    [super drawBezelWithFrame:frame inView:controlView];
    
    // Overlay our our selection highlight
    if ([self isHighlighted] || [self state])
    {
        NSRect highlightFrame = NSInsetRect(frame, 1.0, 2.0);
        
        NSGradient *gradient = [KSInspectorTabCell iWorkButtonHighlightGradient];
        [gradient drawInRect:highlightFrame angle:90.0f];
    }
}

@end
