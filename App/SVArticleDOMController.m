//
//  SVArticleDOMController.m
//  Sandvox
//
//  Created by Mike on 28/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVArticleDOMController.h"

#import "SVAttributedHTML.h"
#import "SVCalloutDOMController.h"
#import "KTElementPlugInWrapper+DataSourceRegistration.h"
#import "SVGraphic.h"
#import "SVGraphicFactory.h"
#import "SVHTMLContext.h"
#import "KTPage.h"

#import "KSWebLocation.h"

#import "NSArray+Karelia.h"
#import "NSString+Karelia.h"
#import "NSURL+Karelia.h"

#import "DOMNode+Karelia.h"


@implementation SVArticleDOMController

- (void)dealloc
{
    [_earlyCalloutController release];
    
    [super dealloc];
}

- (void)loadHTMLElementFromDocument:(DOMDocument *)document;
{
    [super loadHTMLElementFromDocument:document];
    
    // Also guess at callout controller
    WEKWebEditorItem *parent = [self parentWebEditorItem];
    NSUInteger index = [[parent childWebEditorItems] indexOfObjectIdenticalTo:self];
    if (index >= 1)
    {
        WEKWebEditorItem *calloutController = [[self childWebEditorItems] firstObjectKS];
        if ([calloutController isKindOfClass:[SVCalloutDOMController class]])
        {
            // Early callouts are those which appear outside our subtree. Have to ensure controller's element is loaded first
            if (![calloutController isHTMLElementCreated])
            {
                [calloutController loadHTMLElementFromDocument:document];
            }
            
            if (![[calloutController HTMLElement] isDescendantOfNode:[self HTMLElement]])
            {
                [self setEarlyCalloutDOMController:(SVCalloutDOMController *)calloutController];
            }
        }
    }
}

#pragma mark Properties

- (BOOL)allowsBlockGraphics; { return YES; }

- (IBAction)insertPagelet:(id)sender;
{
    NSManagedObjectContext *context = [[self representedObject] managedObjectContext];
    
    SVGraphic *graphic = [SVGraphicFactory graphicWithActionSender:sender
                                           insertIntoManagedObjectContext:context];
    
    [self addGraphic:graphic placeInline:NO];
    [graphic awakeFromInsertIntoPage:(id <SVPage>)[[self HTMLContext] page]];
}

#pragma mark Callouts

@synthesize earlyCalloutDOMController = _earlyCalloutController;

- (void)willWriteText:(SVParagraphedHTMLWriter *)writer;
{
    // Write early callouts first
    SVCalloutDOMController *calloutController = [self earlyCalloutDOMController];
    if (calloutController) [self write:writer item:calloutController];
    
    
    
    [super willWriteText:writer];
}

#pragma mark Dragging Destination

- (DOMNode *)childForDraggingInfo:(id <NSDraggingInfo>)sender;
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
            return aNode;
            break;
        }
        
        aNode = [aNode nextSiblingOfClass:[DOMElement class]];
    }
    
    // No match was found, so insert at end
    return nil;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;
{
    return [self draggingUpdated:sender];
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender;
{
    NSDragOperation result = NSDragOperationNone;
    
    
    DOMNode *aNode = [self childForDraggingInfo:sender];
    
    // What action to take though?
    NSDragOperation mask = [sender draggingSourceOperationMask];
    if ([sender draggingSource] == [self webEditor])
    {
        result = mask & NSDragOperationGeneric;
    }
    
    if (!result) result = mask & NSDragOperationCopy;
    if (!result) result = mask & NSDragOperationGeneric;
    
    if (result) 
    {
        [self moveDragCaretToBeforeDOMNode:aNode draggingInfo:sender];
        [[self webEditor] moveDragHighlightToDOMNode:[self HTMLElement]];
    }
    
    
    if (!result)
    {
        [self removeDragCaret];
        [[self webEditor] moveDragHighlightToDOMNode:nil];
    }
        
    return result;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender;
{
    [self removeDragCaret];
    [[self webEditor] moveDragHighlightToDOMNode:nil];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)dragInfo;
{
    BOOL result = NO;
    
    
    // Fallback to inserting a new pagelet from the pasteboard
    NSManagedObjectContext *moc = [[self representedObject] managedObjectContext];
    NSPasteboard *pasteboard = [dragInfo draggingPasteboard];
    
    NSArray *preferredPlacements = nil;
    NSArray *pagelets = [SVGraphic graphicsFromPasteboard:pasteboard
                           insertIntoManagedObjectContext:moc
                                      preferredPlacements:&preferredPlacements];
    
    
    // Fallback to generic pasteboard support
    if ([pagelets count] < 1)
    {
        pagelets = [KTElementPlugInWrapper graphicsFomPasteboard:pasteboard
                                  insertIntoManagedObjectContext:moc];
    }
    
    
    // Insert the pagelets
    if ([pagelets count] && [[self webEditor] shouldChangeText:self])
    {
        // Generate HTML
        NSMutableString *html = [[NSMutableString alloc] init];
        SVWebEditorHTMLContext *context = [[SVWebEditorHTMLContext alloc] initWithStringWriter:html];
        [context copyPropertiesFromContext:[self HTMLContext]];
        
        for (SVGraphic *aGraphic in pagelets)
        {
            [aGraphic writeHTML:context placement:SVGraphicPlacementCallout];
        }
        
        
        // Insert HTML into DOM, replacing caret
        DOMNode *node = [self childForDraggingInfo:dragInfo];
        [self moveDragCaretToBeforeDOMNode:node draggingInfo:dragInfo];
        
        if (_dragCaret)
        {
            [self replaceDragCaretWithHTMLString:html];
        }
        else
        {
            DOMHTMLDocument *doc = (DOMHTMLDocument *)[[self HTMLElement] ownerDocument];
            
            DOMDocumentFragment *fragment = [doc
                                             createDocumentFragmentWithMarkupString:html
                                             baseURL:[context baseURL]];
            
            [[self textHTMLElement] insertBefore:fragment refChild:node];
        }
        [html release];
        
        
        // Insert controllers
        for (WEKWebEditorItem *anItem in [context webEditorItems])
        {
            // Web Editor View Controller will pick up the insertion in its delegate method and handle the various side-effects.
            if (![anItem parentWebEditorItem]) [self addChildWebEditorItem:anItem];
        }
        [context release];
        
        
        // Remove source too?
        NSDragOperation mask = [dragInfo draggingSourceOperationMask];
        if (mask & NSDragOperationMove | mask & NSDragOperationGeneric)
        {
            [[self webEditor] removeDraggedItems];
        }
        
        
        // Finish edit
        [[self webEditor] didChangeText];
        result = YES;
    }
    
    
    
    
    
    return result;
}

- (NSArray *)registeredDraggedTypes;
{
    NSMutableSet *result = [[NSMutableSet alloc] initWithArray:
                            [SVGraphicFactory graphicPasteboardTypes]];
    
    [result addObjectsFromArray:[NSAttributedString attributedHTMStringPasteboardTypes]];
    [result addObject:kSVGraphicPboardType];
    
    // Weed out string and image types since we want Web Editor to handle them.
    [result minusSet:
     [NSSet setWithArray:[NSImage imageUnfilteredPasteboardTypes]]];
    [result removeObject:NSStringPboardType];
    [result removeObject:WebArchivePboardType];
    [result removeObject:NSHTMLPboardType];
    [result removeObject:NSRTFDPboardType];
    [result removeObject:NSRTFPboardType];
    
                      

    
    NSArray *result2 = [result allObjects];
    [result release];
    return result2;
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

- (void)moveDragCaretToBeforeDOMNode:(DOMNode *)node draggingInfo:(id <NSDraggingInfo>)dragInfo;
{
    DOMRange *range = [[[self HTMLElement] ownerDocument] createRange];
    if (node)
    {
        [range setStartBefore:node];
    }
    else
    {
        [range setStartAfter:[[self textHTMLElement] lastChild]];
    }
    
    [[self webEditor] moveDragCaretToDOMRange:range];
    return;
    
    
    // Do we actually need do anything?
    if (node)
    {
        if (node == _dragCaret || [_dragCaret nextSibling] == node) return;
    }
    else
    {
        if ([[self textHTMLElement] lastChild] == node) return;
    }
    
    
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
    
    NSNumber *height = [NSNumber numberWithFloat:[[dragInfo draggedImage] size].height];
    [style setHeight:[NSString stringWithFormat:@"%@px", height]];
}

- (void)replaceDragCaretWithHTMLString:(NSString *)html;
{
    OBASSERT(_dragCaret);
    
    [(DOMHTMLElement *)_dragCaret setOuterHTML:html];
    
    [_dragCaret release]; _dragCaret = nil;
}

#pragma mark Hit-Test

- (WEKWebEditorItem *)hitTestDOMNode:(DOMNode *)node
{
    // Early callout controller sits outside our HTML element, so test it specially
    WEKWebEditorItem *result = [[self earlyCalloutDOMController] hitTestDOMNode:node];
    
    if (!result)
    {
        result = [super hitTestDOMNode:node];
    }
    
    return result;
}

@end


@implementation SVArticle (SVArticleDOMController)
- (Class)DOMControllerClass { return [SVArticleDOMController class]; }
@end

