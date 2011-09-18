//
//  SVTextInspector.m
//  Sandvox
//
//  Created by Mike on 22/07/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVTextInspector.h"

#import "SVEditingController.h"
#import "WEKWebEditorView.h"


@interface SVTextInspector ()
@property(nonatomic, retain, readwrite) SVEditingController *editingController;
@end


#pragma mark -


@implementation SVTextInspector

- (void)dealloc;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:WEKEditingControllerDidChangeSelectionNotification
                                                  object:nil];
    
    [_editingController release];
    
    [super dealloc];
}

- (void)viewDidLoad;
{
    [super viewDidLoad];
    
    //[oIndentLevelFormatter setPartialStringValidationEnabled:YES];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(selectionDidChange:)
                                                 name:WEKEditingControllerDidChangeSelectionNotification
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
    SVEditingController *controller = [NSApp targetForAction:@selector(listIndentLevel)];
    if (controller != [self editingController])
    {
        [self setEditingController:controller];
    }
    
    NSNumber *tag = [controller listTypeTag];
    if ([tag isKindOfClass:[NSNumber class]])
    {
        [oListPopUp selectItemAtIndex:[tag unsignedIntegerValue]];
    }
    else
    {
        [oListPopUp selectItem:nil];
    }
        
    
    BOOL enable = (controller != nil);
    if ([controller respondsToSelector:@selector(validateMenuItem:)])
    {
        enable = ([controller validateMenuItem:[oListPopUp itemAtIndex:0]] ||
                  [controller validateMenuItem:[oListPopUp itemAtIndex:1]] ||
                  [controller validateMenuItem:[oListPopUp itemAtIndex:2]]);
    }
    [oListPopUp setEnabled:enable];
    
        
    
    SVValidatedUserInterfaceItem *item = [[SVValidatedUserInterfaceItem alloc] init];
    
    [item setAction:@selector(outdent:)];
    controller = [NSApp targetForAction:@selector(outdent:)];
    enable = [controller validateUserInterfaceItem:item];
    [oIndentLevelSegmentedControl setEnabled:enable forSegment:0];
    
    [item setAction:@selector(indent:)];
    enable = [controller validateUserInterfaceItem:item];
    [oIndentLevelSegmentedControl setEnabled:enable forSegment:1];
    
    [item release];
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

@synthesize editingController = _editingController;

@end
