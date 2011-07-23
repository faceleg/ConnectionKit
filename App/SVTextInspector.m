//
//  SVTextInspector.m
//  Sandvox
//
//  Created by Mike on 22/07/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVTextInspector.h"


@implementation SVTextInspector

- (IBAction)changeAlignment:(NSSegmentedControl *)sender;
{
    switch ([[sender cell] tagForSegment:[sender selectedSegment]])
    {
        case NSLeftTextAlignment:
            [NSApp sendAction:@selector(alignLeft:) to:nil from:self];
            break;
            
        case NSCenterTextAlignment:
            [NSApp sendAction:@selector(alignCenter:) to:nil from:self];
            break;
            
        case NSRightTextAlignment:
            [NSApp sendAction:@selector(alignRight:) to:nil from:self];
            break;
            
        case NSJustifiedTextAlignment:
            [NSApp sendAction:@selector(alignJustified:) to:nil from:self];
            break;
    }
}

- (void)refresh
{
    [super refresh];
    
    [oAlignmentSegmentedControl setSelected:NO forSegment:[oAlignmentSegmentedControl selectedSegment]];
}

@end
