//
//  SVGraphicDOMController.m
//  Sandvox
//
//  Created by Mike on 23/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVGraphicDOMController.h"
#import "SVGraphic.h"

#import "SVBodyTextDOMController.h"
#import "SVTextAttachment.h"
#import "SVWebEditorView.h"


@implementation SVGraphicDOMController

- (SVBodyTextDOMController *)enclosingBodyTextDOMController;
{
    id result = [self parentWebEditorItem];
    while (result && ![result isKindOfClass:[SVBodyTextDOMController class]])
    {
        result = [result parentWebEditorItem];
    }
    return result;
}

- (void)setEditing:(BOOL)editing;
{
    [super setEditing:editing];
    
    
    if (editing)
    {
        [[[self HTMLElement] style] setProperty:@"-webkit-user-select"
                                          value:@"auto"
                                       priority:@""];
    }
    else
    {
        [[[self HTMLElement] style] removeProperty:@"-webkit-user-select"];
    }
}

@end


#pragma mark -


@implementation SVGraphic (SVDOMController)

- (Class)DOMControllerClass;
{
    return [SVGraphicDOMController class];
}

@end
