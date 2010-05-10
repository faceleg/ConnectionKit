//
//  SVGraphicDOMController.m
//  Sandvox
//
//  Created by Mike on 23/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVGraphicDOMController.h"
#import "SVGraphic.h"

#import "SVRichTextDOMController.h"
#import "SVTextAttachment.h"
#import "WebEditingKit.h"


@implementation SVGraphicDOMController

- (BOOL)isSelectable { return YES; }

- (SVRichTextDOMController *)enclosingBodyTextDOMController;
{
    id result = [self parentWebEditorItem];
    while (result && ![result isKindOfClass:[SVRichTextDOMController class]])
    {
        result = [result parentWebEditorItem];
    }
    return result;
}

- (void)setEditing:(BOOL)editing;
{
    [super setEditing:editing];
    
    
    // Make sure we're selectable while editing
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

#pragma mark NSDraggingSource

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal;
{
    NSDragOperation result = [super draggingSourceOperationMaskForLocal:isLocal];
    
    if ([(SVGraphic *)[self representedObject] isCallout])
    {
        // Don't allow callouts to be moved at the moment.
        if (result & NSDragOperationMove) result = result - NSDragOperationMove;
        if (result & NSDragOperationGeneric) result = result - NSDragOperationGeneric;
    }
    
    return result;
}

@end


#pragma mark -


@implementation SVGraphic (SVDOMController)

- (Class)DOMControllerClass;
{
    return [SVGraphicDOMController class];
}

@end
