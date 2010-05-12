//
//  SVPageBodyTextDOMController.m
//  Sandvox
//
//  Created by Mike on 28/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVPageBodyTextDOMController.h"

#import "SVAttributedHTML.h"
#import "SVCalloutDOMController.h"
#import "KTElementPlugInWrapper+DataSourceRegistration.h"
#import "SVGraphic.h"
#import "SVGraphicFactoryManager.h"
#import "SVHTMLContext.h"
#import "KTPage.h"

#import "KSWebLocation.h"

#import "NSString+Karelia.h"
#import "NSURL+Karelia.h"

#import "DOMNode+Karelia.h"


@implementation SVPageBodyTextDOMController

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
        WEKWebEditorItem *calloutController = [[parent childWebEditorItems] objectAtIndex:index-1];
        if ([calloutController isKindOfClass:[SVCalloutDOMController class]])
        {
            [self setEarlyCalloutDOMController:(SVCalloutDOMController *)calloutController];
        }
    }
}

#pragma mark Properties

- (BOOL)allowsBlockGraphics; { return YES; }

- (IBAction)insertPagelet:(id)sender;
{
    NSManagedObjectContext *context = [[self representedObject] managedObjectContext];
    
    SVGraphic *graphic = [SVGraphicFactoryManager graphicWithActionSender:sender
                                           insertIntoManagedObjectContext:context];
    
    [self addGraphic:graphic placeInline:NO];
    [graphic awakeFromInsertIntoPage:(id <SVPage>)[[self HTMLContext] page]];
}

#pragma mark Callouts

@synthesize earlyCalloutDOMController = _earlyCalloutController;

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
    
    
    // Ignore images
    NSArray *locations = [KSWebLocation webLocationsFromPasteboard:[sender draggingPasteboard]];
    for (KSWebLocation *aLocation in locations)
    {
        NSString *extension = [[aLocation URL] pathExtension];
        NSString *type = [NSString UTIForFilenameExtension:extension];
        if ([type conformsToUTI:(NSString *)kUTTypeImage]) return result;
    }
    
    
    DOMNode *aNode = [self childForDraggingInfo:sender];
    if (aNode)
    {
        // What action to take though?
        NSDragOperation mask = [sender draggingSourceOperationMask];
        if ([sender draggingSource] == [self webEditor])
        {
            result = mask & NSDragOperationGeneric;
        }
        
        if (!result) result = mask & NSDragOperationCopy;
        if (!result) result = mask & NSDragOperationGeneric;
        
        if (result) [self moveDragCaretToBeforeDOMNode:aNode draggingInfo:sender];
    }
    
    if (!result) [self removeDragCaret];
        
    return result;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender;
{
    [self removeDragCaret];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)dragInfo;
{
    BOOL result = NO;
    
    
    // Fallback to inserting a new pagelet from the pasteboard
    NSManagedObjectContext *moc = [[self representedObject] managedObjectContext];
    NSPasteboard *pasteboard = [dragInfo draggingPasteboard];
    
    NSArray *pagelets = [NSAttributedString pageletsFromPasteboard:pasteboard
                                  insertIntoManagedObjectContext:moc];
    
    
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
        
        [SVContentObject writeContentObjects:pagelets inContext:context];
        
        
        // Insert HTML into DOM, replacing caret
        [self moveDragCaretToBeforeDOMNode:[self childForDraggingInfo:dragInfo]
                              draggingInfo:dragInfo];
        OBASSERT(_dragCaret);
        
        [(DOMHTMLElement *)_dragCaret setOuterHTML:html];
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
    NSSet *plugInTypes = [KTElementPlugInWrapper setOfAllDragSourceAcceptedDragTypesForPagelets:YES];
    
    NSMutableSet *result = [plugInTypes mutableCopy];
    [result addObjectsFromArray:[NSAttributedString attributedHTMStringPasteboardTypes]];
    
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

@end


@implementation SVPageBody (SVPageBodyTextDOMController)
- (Class)DOMControllerClass { return [SVPageBodyTextDOMController class]; }
@end

