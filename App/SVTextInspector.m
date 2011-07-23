//
//  SVTextInspector.m
//  Sandvox
//
//  Created by Mike on 22/07/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVTextInspector.h"

#import "WEKWebViewEditing.h"


@implementation SVTextInspector

- (void)dealloc;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:WebViewDidChangeSelectionNotification
                                                  object:nil];
    
    [super dealloc];
}

- (void)viewDidLoad;
{
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(selectionDidChange:)
                                                 name:WebViewDidChangeSelectionNotification
                                               object:nil];
}

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
    
    
    // Try to validate existing alignment as it's likely to remain
    NSTextAlignment alignment = -1;
    
    id textEditor = [NSApp targetForAction:@selector(wek_alignment)];
    if (textEditor)
    {
        [oAlignmentSegmentedControl setEnabled:YES];
        alignment = [textEditor wek_alignment];
    }
    else
    {
        [oAlignmentSegmentedControl setEnabled:NO];
    }
    
    if (![oAlignmentSegmentedControl selectSegmentWithTag:alignment])
    {
        [oAlignmentSegmentedControl setSelected:NO forSegment:[oAlignmentSegmentedControl selectedSegment]];
    }
}

- (void)selectionDidChange:(NSNotification *)notification;
{
    [self refresh];
}

@end
