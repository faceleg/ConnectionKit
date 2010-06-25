//
//  SVWebEditorView.m
//  Sandvox
//
//  Created by Mike on 22/06/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVWebEditorView.h"


@implementation SVWebEditorView

- (IBAction)placeInline:(id)sender;
{
    if (![[self delegate] webEditor:self doCommandBySelector:_cmd]) NSBeep();
}

- (IBAction)placeAsCallout:(id)sender;
{
    if (![[self delegate] webEditor:self doCommandBySelector:_cmd]) NSBeep();
}

- (IBAction)placeInSidebar:(id)sender;
{
    if (![[self delegate] webEditor:self doCommandBySelector:_cmd]) NSBeep();
}

@end
