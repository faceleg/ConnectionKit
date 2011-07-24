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
        alignment = [textEditor wek_alignment];
    }
    
    if (![oAlignmentSegmentedControl selectSegmentWithTag:alignment])
    {
        [oAlignmentSegmentedControl setSelected:NO forSegment:[oAlignmentSegmentedControl selectedSegment]];
    }
    
    
    // Alignment
    if ([textEditor conformsToProtocol:@protocol(NSUserInterfaceValidations)])
    {
        [oAlignmentSegmentedControl setEnabled:YES];
        
        NSMenuItem *fakeMenu = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(alignLeft:) keyEquivalent:@""];
        [oAlignmentSegmentedControl setEnabled:[textEditor validateUserInterfaceItem:fakeMenu] forSegment:0];
        
        [fakeMenu setAction:@selector(alignCenter:)];
        [oAlignmentSegmentedControl setEnabled:[textEditor validateUserInterfaceItem:fakeMenu] forSegment:1];
        
        [fakeMenu setAction:@selector(alignRight:)];
        [oAlignmentSegmentedControl setEnabled:[textEditor validateUserInterfaceItem:fakeMenu] forSegment:2];
        
        [fakeMenu setAction:@selector(alignJustified:)];
        [oAlignmentSegmentedControl setEnabled:[textEditor validateUserInterfaceItem:fakeMenu] forSegment:3];
        
        [fakeMenu release];
    }
    else
    {
        [oAlignmentSegmentedControl setEnabled:NO];
    }
    
    
    // Bullets
    id listEditor = [NSApp targetForAction:@selector(unorderedList)];
    if ([listEditor unorderedList])
    {
        [self setListStyle:1];
    }
    else if ([listEditor orderedList])
    {
        [self setListStyle:2];
    }
    else
    {
        // Sadly I haven't found an API yet that informs selection is part list, part paragraph
        [self setListStyle:0];
    }
    
    BOOL enable = YES;
    if ([listEditor respondsToSelector:@selector(validateMenuItem:)])
    {
        enable = ([listEditor validateMenuItem:[oListPopUp itemAtIndex:0]] ||
                  [listEditor validateMenuItem:[oListPopUp itemAtIndex:1]] ||
                  [listEditor validateMenuItem:[oListPopUp itemAtIndex:2]]);
    }
    [oListPopUp setEnabled:enable];
}

- (void)selectionDidChange:(NSNotification *)notification;
{
    [self refresh];
}

#pragma mark Lists

@synthesize listStyle = _listStyle;

@end
