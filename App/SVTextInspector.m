//
//  SVTextInspector.m
//  Sandvox
//
//  Created by Mike on 22/07/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVTextInspector.h"

#import "SVWebViewSelectionController.h"
#import "WEKWebEditorView.h"
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

#pragma mark Lists

- (void)refreshList;
{
    // Bullets
    id listEditor = [NSApp targetForAction:@selector(selectedListTag)];
    NSString *tag = [listEditor selectedListTag];
    BOOL hideListDetails = YES;
    
    if (tag == NSMultipleValuesMarker)
    {
        [oListPopUp selectItem:nil];
    }
    else if ([tag isEqualToString:@"UL"])
    {
        [oListPopUp selectItemAtIndex:1];
        hideListDetails = NO;
    }
    else if ([tag isEqualToString:@"OL"])
    {
        [oListPopUp selectItemAtIndex:2];
        hideListDetails = NO;
    }
    else
    {
        [oListPopUp selectItemAtIndex:0];
    }
    
    [oListDetailsView setHidden:hideListDetails];
    if (!hideListDetails)
    {
        [oSelectionController setSelection:[listEditor selectedDOMRange]];
    }
    
    
    BOOL enable = (listEditor != nil);
    if ([listEditor respondsToSelector:@selector(validateMenuItem:)])
    {
        enable = ([listEditor validateMenuItem:[oListPopUp itemAtIndex:0]] ||
                  [listEditor validateMenuItem:[oListPopUp itemAtIndex:1]] ||
                  [listEditor validateMenuItem:[oListPopUp itemAtIndex:2]]);
    }
    [oListPopUp setEnabled:enable];
    
    
    [oIndentLevelSegmentedControl setEnabled:(listEditor != nil)];
    if ([listEditor conformsToProtocol:@protocol(NSUserInterfaceValidations)])
    {
        SVValidatedUserInterfaceItem *item = [[SVValidatedUserInterfaceItem alloc] init];
        
        [item setAction:@selector(outdent:)];
        enable = [listEditor validateUserInterfaceItem:item];
        [oIndentLevelSegmentedControl setEnabled:enable forSegment:0];
        
        [item setAction:@selector(indent:)];
        enable = [listEditor validateUserInterfaceItem:item];
        [oIndentLevelSegmentedControl setEnabled:enable forSegment:1];
        
        [item release];
    }
}

- (IBAction)changeIndent:(NSSegmentedControl *)sender;
{
    switch ([sender selectedSegment])
    {
        case 0:
            [NSApp sendAction:@selector(outdent:) to:nil from:self];
            break;
            
        case 1:
            [NSApp sendAction:@selector(indent:) to:nil from:self];
            break;
    }
}

#pragma mark General

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
    
    
    [self refreshList];
}

- (void)selectionDidChange:(NSNotification *)notification;
{
    [self refresh];
}

@end
