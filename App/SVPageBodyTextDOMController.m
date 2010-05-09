//
//  SVPageBodyTextDOMController.m
//  Sandvox
//
//  Created by Mike on 28/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVPageBodyTextDOMController.h"

#import "SVGraphic.h"
#import "SVGraphicFactoryManager.h"
#import "SVHTMLContext.h"
#import "KTPage.h"

#import "DOMNode+Karelia.h"


@implementation SVPageBodyTextDOMController

#pragma mark Properties

- (BOOL)allowsBlockGraphics; { return YES; }

- (IBAction)insertPagelet:(id)sender;
{
    NSManagedObjectContext *context = [[self representedObject] managedObjectContext];
    
    SVGraphic *graphic = [SVGraphicFactoryManager graphicWithActionSender:sender
                                           insertIntoManagedObjectContext:context];
    
    [self addGraphic:graphic placeInline:NO];
    [graphic awakeFromInsertIntoPage:(id <SVPage>)[[self HTMLContext] currentPage]];
}

#pragma mark Dragging Destination

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;
{
    return [self draggingUpdated:sender];
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender;
{
    DOMElement *element = [self HTMLElement];
    NSPoint location = [[element documentView] convertPointFromBase:[sender draggingLocation]];
    
    DOMNode *aNode = [[self textHTMLElement] firstChildOfClass:[DOMElement class]];
    while (aNode)
    {
        NSRect bounds = [aNode boundingBox];
        CGFloat mid = NSMidY(bounds);
        
        if (location.y < mid)
        {
            [self moveDragCaretToBeforeDOMNode:aNode];
            break;
        }
        
        aNode = [aNode nextSiblingOfClass:[DOMElement class]];
    }
    
    if (!aNode)
    {
        // No match was found, so insert at end
    }
        
    
    
    return NSDragOperationCopy;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender;
{
    [self removeDragCaret];
}

- (WEKWebEditorItem *)hitTestDOMNode:(DOMNode *)node draggingInfo:(id <NSDraggingInfo>)info;
{
    WEKWebEditorItem *result = [super hitTestDOMNode:node draggingInfo:info];
    
    if (!result)
    {
        result = self;
    }
    
    return result;
}

#pragma mark Drag Caret

- (void)removeDragCaret;
{
    // Schedule removal
    [[_dragCaret style] setHeight:@"0px"];
    
    [_dragCaret performSelector:@selector(ks_removeFromParentNode)
                     withObject:nil
                     afterDelay:0.25];
    
    [_dragCaret release]; _dragCaret = nil;
}

- (void)moveDragCaretToBeforeDOMNode:(DOMNode *)node;
{
    // Do we actually need do anything?
    if (node == _dragCaret || [_dragCaret nextSibling] == node) return;
    
    
    [self removeDragCaret];
    
    // Create rough approximation of a pagelet
    OBASSERT(!_dragCaret);
    _dragCaret = [[[self HTMLElement] ownerDocument] createElement:@"div"];
    [_dragCaret retain];
    [_dragCaret setAttribute:@"class" value:@"pagelet wide center untitled"];
    
    DOMCSSStyleDeclaration *style = [_dragCaret style];
    [style setMarginTop:@"0px"];
    [style setMarginBottom:@"0px"];
    [style setPaddingTop:@"0px"];
    [style setPaddingBottom:@"0px"];
    
    [style setProperty:@"-webkit-transition-duration" value:@"0.25s" priority:@""];
    
    [[self textHTMLElement] insertBefore:_dragCaret refChild:node];
    [style setHeight:@"75px"];
}

@end


@implementation SVPageBody (SVPageBodyTextDOMController)
- (Class)DOMControllerClass { return [SVPageBodyTextDOMController class]; }
@end