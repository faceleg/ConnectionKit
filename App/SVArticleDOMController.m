//
//  SVArticleDOMController.m
//  Sandvox
//
//  Created by Mike on 28/04/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVArticleDOMController.h"

#import "SVAttributedHTML.h"
#import "SVCalloutDOMController.h"
#import "SVContentDOMController.h"
#import "SVGraphicFactory.h"
#import "SVMigrationHTMLWriterDOMAdaptor.h"
#import "KTPage.h"
#import "SVSidebarPageletsController.h"
#import "SVTextAttachment.h"
#import "SVWebEditorViewController.h"
#import "WEKWebViewEditing.h"

#import "NSArray+Karelia.h"
#import "NSColor+Karelia.h"
#import "NSResponder+Karelia.h"
#import "NSString+Karelia.h"
#import "NSURL+Karelia.h"
#import "KSObjectKeyPathPair.h"

#import "DOMNode+Karelia.h"
#import "DOMRange+Karelia.h"
#import "DOMTreeWalker+Karelia.h"

#import "KSWebLocation.h"


@interface DOMNode (KSHTMLWriter)
- (BOOL)ks_isDescendantOfDOMNode:(DOMNode *)possibleAncestor;
@end
@interface DOMElement (SVParagraphedHTMLWriter)
- (DOMNodeList *)getElementsByClassName:(NSString *)name;
@end


#pragma mark -


@interface SVArticleAttachmentsController : NSArrayController
@end


#pragma mark -


@implementation SVArticleDOMController

- (id)init;
{
    [super init];
    
    // We'll accept pretty much anything
    [self registerForDraggedTypes:NSARRAY((NSString *)kUTTypeItem, NSFilenamesPboardType)];
    [self registerForDraggedTypes:[NSAttributedString attributedHTMStringPasteboardTypes]];
    
    return self;
}

- (void)dealloc
{
    [_earlyCalloutController release];
    
    [super dealloc];
}

- (void)loadHTMLElementFromDocument:(DOMDocument *)document;
{
    [super loadHTMLElementFromDocument:document];
    
    if (![self isHTMLElementCreated]) return;
    
    
    // Text element is the kBlock
    id textElement = [[[self HTMLElement] getElementsByClassName:@"kBlock"] item:0];
    [self setTextHTMLElement:textElement];
    
    
    // Also guess at callout controller
    WEKWebEditorItem *parent = [self parentWebEditorItem];
    NSUInteger index = [[parent childWebEditorItems] indexOfObjectIdenticalTo:self];
    if (index >= 1)
    {
        WEKWebEditorItem *calloutController = [[self childWebEditorItems] firstObjectKS];
        if ([calloutController isKindOfClass:[SVCalloutDOMController class]])
        {
            // Early callouts are those which appear outside our subtree. Have to ensure controller's element is loaded first
            if (![[calloutController HTMLElement] ks_isDescendantOfElement:[self HTMLElement]])
            {
                [self setEarlyCalloutDOMController:(SVCalloutDOMController *)calloutController];
            }
        }
    }
    
    
    // Catch mouse downs from #page. It will retain us.
    [[self mouseDownSelectionFallbackDOMElement]
     addEventListener:@"mousedown" listener:[self eventsListener] useCapture:NO];
}

#pragma mark Properties

- (BOOL)allowsPagelets; { return YES; }

- (void)addGraphic:(SVGraphic *)graphic;
{
    // If graphic is small enough to go in sidebar, place there instead.
    NSNumber *width = [graphic width];
    if (width && [width unsignedIntegerValue] <= 200)
    {
        // Doesn't make sense if there is no sidebar! #103205
        if ([[[(SVArticle *)[self representedObject] page] showSidebar] boolValue])
        {
            [[self webEditorViewController] performSelector:@selector(_insertPageletInSidebar:)
                                                 withObject:graphic];
            
            return;
        }
        
        // No sidebar? Make it a callout. #103215
        [self addGraphic:graphic placeInline:NO];
        [[graphic textAttachment] setPlacement:[NSNumber numberWithInt:SVGraphicPlacementCallout]];
    }
    else
    {
        [self addGraphic:graphic placeInline:NO];
    }
}

#pragma mark Selection fallback

- (DOMElement *)mouseDownSelectionFallbackDOMElement;
{
    return [[[self HTMLElement] ownerDocument] getElementById:@"page"];
}

- (void)handleEvent:(DOMMouseEvent *)event;
{
    if ([[event type] isEqualToString:@"mousedown"])
    {
        if ([[self textHTMLElement] ks_isDescendantOfDOMNode:(DOMNode *)[event target]])
        {
            WEKWebEditorView *webEditor = [self webEditor];
            
            DOMRange *fallbackRange = [[[self HTMLElement] ownerDocument] createRange];
            DOMNode *textElement = [self textHTMLElement];
            [fallbackRange setStart:textElement offset:[[textElement childNodes] length]];
            
            if ([[webEditor delegate] webEditor:webEditor
                   shouldChangeSelectedDOMRange:[webEditor selectedDOMRange]
                                     toDOMRange:fallbackRange
                                       affinity:0
                                          items:nil
                                 stillSelecting:NO])
            {
                [[webEditor window] makeFirstResponder:webEditor];
                [webEditor setSelectedDOMRange:fallbackRange affinity:0];
                
                [event preventDefault];
                [event stopPropagation];
            }
        }
    }
    else
    {
        [super handleEvent:event];
    }
}

#pragma mark Callouts

@synthesize earlyCalloutDOMController = _earlyCalloutController;

- (void)writeText:(SVParagraphedHTMLWriterDOMAdaptor *)writer;
{
    // Write early callouts first
    SVCalloutDOMController *calloutController = [self earlyCalloutDOMController];
    if (calloutController)
    {
        [self write:writer
         DOMElement:[calloutController HTMLElement]
               item:calloutController];
    }
    
    
    
    [super writeText:writer];
}

#pragma mark Insertion

- (DOMRange *)insertionRangeForGraphic:(SVGraphic *)graphic;
{
    DOMRange *result = [super insertionRangeForGraphic:graphic];
    
    NSNumber *wrap = [[graphic textAttachment] causesWrap];
    if (!wrap || [wrap boolValue])
    {
        // Perform the insertion at top-level. #101122
        while ([result startContainer] != [self textHTMLElement])
        {
            [result setStartBefore:[result startContainer]];
        }
        [result collapse:YES];
    }
    
    return result;
}

- (BOOL)insertGraphics:(NSArray *)graphics beforeDOMNode:(DOMNode *)refNode;
{
    BOOL result = NO;
    
    
    // Insert into text
    if ([graphics count])
    {
        DOMRange *range = [[[self HTMLElement] ownerDocument] createRange];
        if (refNode)
        {
            [range setStartBefore:refNode];
        }
        else
        {
            [range setStart:[self textHTMLElement] offset:[[[self textHTMLElement] childNodes] length]];
        }
        
        for (SVGraphic *aGraphic in graphics)
        {
            // Give pagelet a chance to resize etc.
            [self insertGraphic:aGraphic range:range];
            [aGraphic pageDidChange:[[self HTMLContext] page]];
        }
        
        
        // Select those graphics. #93340
        NSArrayController *controller = [[self webEditorViewController] graphicsController];
        [controller setSelectedObjects:graphics];
        
        
        result = YES;
    }
    
    
    return result;
}

- (void)insertGraphic:(SVGraphic *)graphic range:(DOMRange *)insertionRange;
{
    // Since the graphic's not generated as part of text, register placement as a dependency
    KSObjectKeyPathPair *dependency = [[KSObjectKeyPathPair alloc]
                                       initWithObject:graphic
                                       keyPath:@"textAttachment.placement"];
    [self addDependency:dependency];
    [dependency release];
    
    
    [super insertGraphic:graphic range:insertionRange];
}

- (BOOL)webEditorTextShouldInsertNode:(DOMNode *)node
                    replacingDOMRange:(DOMRange *)range
                          givenAction:(WebViewInsertAction)action;
{
    // Strip out <br class="Apple-interchange-newline" />
    // WebKit inserts these when creating a WebArchive out of something it thinks deserves them (display:block elements I believe). Thus, we strip back out since messes up formatting.
    DOMNodeIterator *iterator = [[node ownerDocument] createNodeIterator:node whatToShow:DOM_SHOW_ELEMENT filter:nil expandEntityReferences:NO];
    
    DOMElement *aNode;
    while (aNode = (DOMElement *)[iterator nextNode])
    {
        if ([[aNode getAttribute:@"class"] isEqualToString:@"Apple-interchange-newline"])
        {
            [[aNode parentNode] removeChild:aNode];
        }
    }
    
    [iterator detach];
    
    
    BOOL result = [super webEditorTextShouldInsertNode:node replacingDOMRange:range givenAction:action];
    return result;
}

#pragma mark Placement

- (void)moveToBlockLevel:(id)sender;
{
    // It's a bit of a tricky manoeuvre. Want to pull the graphic back to the start of its paragraph
    
    
    WEKWebEditorView *webEditor = [self webEditor];

    // Move graphic back to be top-level. Finding the right element to operate on can be a little tricky. Normally it's the controller's own node, but in the case of callouts, want to operate on the callout, not element. #83445
    WEKWebEditorItem *controller = [webEditor selectedItem];
    while ([controller parentWebEditorItem] != self)
    {
        controller = [controller parentWebEditorItem];
    }
    
    DOMElement *element = [controller HTMLElement];
    DOMNode *parent = [element parentNode];
    
    while (parent != [self textHTMLElement])
    {
        // Ask permission first. Doing once per loop means no permission is asked if no change is made
        if (![webEditor shouldChangeText:self]) break;
        
        [[parent parentNode] insertBefore:element refChild:parent];
        parent = [element parentNode];
    }
    
    // Push the change to the model ready for the update to pick it up
    [webEditor didChangeText];
}

- (IBAction)placeInline:(id)sender;    // tells all selected graphics to become placed as block
{
    SVWebEditorViewController *viewController = [self webEditorViewController];
    OBASSERT(viewController);
    
    for (SVGraphic *aGraphic in [[viewController graphicsController] selectedObjects])
    {
        SVGraphicPlacement placement = [[aGraphic placement] integerValue];
        switch (placement)
        {
            case SVGraphicPlacementCallout:
                // The graphic be transformed on the spot. #79017
                [[aGraphic textAttachment] setPlacement:[NSNumber numberWithInt:SVGraphicPlacementInline]];
                break;
                
            case SVGraphicPlacementInline:
                // Nothing to do
                break;
                
            default:
                // er, what on earth is it then?
                NSBeep();
        }
    }
}

- (IBAction)placeAsCallout:(id)sender;
{
    // Can't have any inline elements
    [self moveToBlockLevel:sender];
    
    
    SVWebEditorViewController *viewController = [self webEditorViewController];
    OBASSERT(viewController);
    
    for (SVGraphic *aGraphic in [[viewController graphicsController] selectedObjects])
    {        
        SVGraphicPlacement placement = [[aGraphic placement] integerValue];
        switch (placement)
        {
            case SVGraphicPlacementCallout:
                break;
                
            case SVGraphicPlacementInline:
                [[aGraphic textAttachment] setPlacement:[NSNumber numberWithInt:SVGraphicPlacementCallout]];
                [aGraphic pageDidChange:[[self HTMLContext] page]];
                break;
        
            default:
                // er, what on earth is it then?
                NSBeep();
        }
    }
}

- (IBAction)placeInSidebar:(id)sender;
{
    // Insert copies into sidebar
    SVWebEditorHTMLContext *context = [self HTMLContext];
    
    SVSidebarPageletsController *sidebarController = [context sidebarPageletsController];
    if (!sidebarController) return NSBeep();
    
    
    SVWebEditorViewController *viewController = [self webEditorViewController]; OBASSERT(viewController);
    NSArrayController *graphicsController = [viewController graphicsController];
    
    
    NSArray *graphics = [graphicsController selectedObjects];
    NSMutableArray *sidebarPagelets = [[NSMutableArray alloc] initWithCapacity:[graphics count]];
    
    
    for (SVGraphic *aGraphic in graphics)
    {
        // Serialize
        id serializedPagelet = [aGraphic serializedProperties];
        
        // Deserialize into controller
        if (![sidebarController managedObjectContext]) [sidebarController bindContentToPage]; // #108442
        SVGraphic *pagelet = [sidebarController addObjectFromSerializedPagelet:serializedPagelet];
        if (pagelet) [sidebarPagelets addObject:pagelet];
    }
    
    
    // Remove originals. For some reason -delete: does not fire change notifications
    [self deleteObjects:self];
    
    
    // Update selection
    BOOL selectInserted = [graphicsController selectsInsertedObjects];
    [graphicsController setSelectsInsertedObjects:YES];
    [graphicsController addObjects:sidebarPagelets];
    [graphicsController setSelectsInsertedObjects:selectInserted];
    
    [sidebarPagelets release];
}


#pragma mark Other Actions

- (void)paste:(id)sender;
{
    // Normally WebView should handle the paste. But we want control of pagelet pastes
    NSPasteboard *pboard = [NSPasteboard generalPasteboard];
    if (![[pboard types] containsObject:kSVGraphicPboardType])
    {
        return [[self webEditor] forceWebViewToPerform:_cmd withObject:sender];
    }
    
    
    // Insert deserialized pagelet from pboard
    NSManagedObjectContext *moc = [[self representedObject] managedObjectContext];
    
    NSArray *attachments = [SVTextAttachment textAttachmentsFromPasteboard:pboard
                                            insertIntoManagedObjectContext:moc];
    NSArray *pagelets = [attachments valueForKey:@"graphic"];
    
    
    // Insert pagelets into text
    DOMNode *refNode = [[[self webEditor] selectedDOMRange] ks_startNode:NULL];
    
    if ([[self webEditor] shouldChangeText:self] &&
        [self insertGraphics:pagelets beforeDOMNode:refNode])
    {
        [[self webEditor] didChangeText];
    }
    else
    {
        NSBeep();
    }
}

- (void)deleteObjects:(id)sender;
{
    WEKWebEditorView *webEditor = [self webEditor];
    if ([webEditor shouldChangeText:self])
    {
        NSArray *selection = [self selectedItems];
        for (SVGraphicDOMController *anItem in selection)
        {
            // Only graphics can be deleted with -delete. #108128
            if ([anItem graphicContainerDOMController] == [anItem parentWebEditorItem])
            {
                [anItem delete];
            }
            else
            {
                [[[self webEditorViewController] graphicsController] removeObject:[anItem representedObject]];
            }
        }
        
        [webEditor didChangeText];
    }
}

#pragma mark Selection

- (NSArray *)selectedItems;
{
    NSArray *objects = [[[self webEditorViewController] graphicsController] selectedObjects];
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:[objects count]];
    
    for (SVGraphic *anObject in objects)
    {
        WEKWebEditorItem *item = [self hitTestRepresentedObject:anObject];
        if (item)
        {
            // Search up to find the highest item
            WEKWebEditorItem *parent = [item parentWebEditorItem];
            while ([parent representedObject] == anObject)
            {
                item = parent; parent = [item parentWebEditorItem];
            }
            
            [result addObject:item];
        }
    }
    
    return result;
}

- (DOMRange *)webEditorSelectionDOMRangeForProposedSelection:(DOMRange *)proposedRange
                                                    affinity:(NSSelectionAffinity)selectionAffinity
                                              stillSelecting:(BOOL)flag;
{
    DOMRange *result = [super webEditorSelectionDOMRangeForProposedSelection:proposedRange
                                                                    affinity:selectionAffinity
                                                              stillSelecting:flag];
    
    BOOL changed = NO;
    
    // If user tries to select paragraph, WebKit has a nasty tendency to include any following block-level graphics. We'll deselect them
    DOMNode *penultimateNode = [[result endContainer] previousSibling];
    if ([penultimateNode parentNode] == [self innerTextHTMLElement])
    {
        WEKWebEditorItem *controller = [self hitTestDOMNode:penultimateNode];
        while (controller != self)
        {
            [result setEndBefore:penultimateNode]; changed = YES;
            
            penultimateNode = [penultimateNode previousSibling];
            controller = (penultimateNode ? [self hitTestDOMNode:penultimateNode] : self);
        }
    }
    
    
    if (changed && result == proposedRange)
    {
        // Have to make a copy to fool caller
        result = [result cloneRange];
    }
    return result;
}

#pragma mark Updating

- (void)willUpdateWithNewChildController:(WEKWebEditorItem *)newChildController;
{
    // Helper method that:
    //  A) swaps the new controller out for an existing one if possible
    //  B) runs scripts for the new controller
    
    
    DOMDocument *doc = [[self HTMLElement] ownerDocument];
    [newChildController loadHTMLElementFromDocument:doc];
    
    
    NSObject *object = [newChildController representedObject];
    if (!object || [object isKindOfClass:[SVCallout class]])
    {
        // Probably a callout, search for a matching one
        NSArray *objects = [newChildController valueForKeyPath:@"childWebEditorItems.representedObject"];
        for (WEKWebEditorItem *anItem in [self childWebEditorItems])
        {
            if (![anItem representedObject] &&
                [objects isEqualToArray:[anItem valueForKeyPath:@"childWebEditorItems.representedObject"]])
            {
                // Bring back the old element!
                DOMElement *element = [newChildController HTMLElement];
                [[element parentNode] replaceChild:[anItem HTMLElement] oldChild:element];
                
                // Bring back the old controller!
                [[newChildController parentWebEditorItem] replaceChildWebEditorItem:newChildController
                                                                               with:anItem];
                return;
            }
        }
        
        //update contents instead. #99997
        for (newChildController in [newChildController childWebEditorItems])
        {
            // Can't call -willUpdateWithNewChildController: as that will recycle an inline DOM controller in some cases. #95985
            [newChildController setNeedsUpdate]; [newChildController updateIfNeeded];
        }
        return;
    }
    
    
    for (WEKWebEditorItem *anOldController in [self childWebEditorItems])
    {
        if ([anOldController representedObject] == object)
        {
            // Bring back the old element!
            DOMElement *element = [newChildController HTMLElement];
            [[element parentNode] replaceChild:[anOldController HTMLElement] oldChild:element];
            
            // Bring back the old controller!
            [[newChildController parentWebEditorItem] replaceChildWebEditorItem:newChildController
                                                                         with:anOldController];
            return;
        }
    }
    
    
    // Force update the controller to run scripts etc. #99997
    [newChildController setNeedsUpdate]; [newChildController updateIfNeeded];
}

- (void)updateWithHTMLString:(NSString *)html items:(NSArray *)items;
{
    // Update DOM
    [[self HTMLElement] setOuterHTML:html];
    
    
    // Re-use any existing graphic controllers when possible
    for (WEKWebEditorItem *aController in items)
    {
        for (WEKWebEditorItem *newChildController in [aController childWebEditorItems])
        {
            [self willUpdateWithNewChildController:newChildController];
        }
    }
    
    
    // Hook up new DOM Controllers
    [[self parentWebEditorItem] replaceChildWebEditorItem:self withItems:items];
    for (SVDOMController *aController in items)
    {
        [aController didUpdateWithSelector:_cmd];
    }
}

- (void)update;
{
    // Tear down dependencies etc.
    [self removeAllDependencies];
    
    
    // Write HTML
    NSMutableString *htmlString = [[NSMutableString alloc] init];
    
    SVWebEditorHTMLContext *context = [[[SVWebEditorHTMLContext class] alloc]
                                       initWithOutputWriter:htmlString inheritFromContext:[self HTMLContext]];
    
    [[context rootDOMController] setWebEditorViewController:[self webEditorViewController]];
    [[self representedObject] writeHTML:context];
    
    
    // Copy top-level dependencies across to parent. #79396
    [context flush];    // you never know!
    for (KSObjectKeyPathPair *aDependency in [[context rootDOMController] dependencies])
    {
        [(SVDOMController *)[self parentWebEditorItem] addDependency:aDependency];
    }
    
    
    // Turn observation back on. #92124
    //[self startObservingDependencies];
    
    
    // Bring end body code into the html
    [context writeEndBodyString];
    
    
    [self updateWithHTMLString:htmlString
                         items:[[context rootDOMController] childWebEditorItems]];
    
    
    // Tidy
    [context close];
    [htmlString release];
    [context release];
}

- (Class)attachmentsControllerClass; { return [SVArticleAttachmentsController class]; }

#pragma mark Editing

- (BOOL)webEditorTextDoCommandBySelector:(SEL)selector
{
    BOOL result = [super webEditorTextDoCommandBySelector:selector];
    
    // Make sure deletions don't throw away wrapped graphics
    if (!result)
    {
        if ([[self class] isDeleteBackwardsSelector:selector])
        {
            DOMRange *selection = [self selectedDOMRange];
            if ([selection collapsed])
            {
                DOMNode *paragraph = [self isDOMRangeStartOfParagraph:selection];
                if (paragraph)
                {
                    WEKWebEditorItem *controller = [self hitTestDOMNode:
                                                    [paragraph previousSiblingOfClass:[DOMElement class]]];
                    
                    if (controller != self && controller)
                    {
                        // Move the controller down so as to avoid deleting it
                        [controller moveDown];
                        //[[self webEditor] moveLeft:self];
                    }
                }
            }
        }
        else if ([[self class] isDeleteForwardsSelector:selector])
        {
            DOMRange *selection = [self selectedDOMRange];
            if ([selection collapsed])
            {
                DOMNode *paragraph = [self isDOMRangeEndOfParagraph:selection];
                if (paragraph)
                {
                    WEKWebEditorItem *controller = [self hitTestDOMNode:
                                                    [paragraph nextSiblingOfClass:[DOMElement class]]];
                    
                    if (controller != self && controller)
                    {
                        // Move the controller down so as to avoid deleting it
                        [controller moveDown];
                        //[[self webEditor] moveLeft:self];
                    }
                }
            }
        }
    }
    
    return result;
}

- (id)newHTMLWritingDOMAdaptorWithOutputStringWriter:(KSStringWriter *)stringWriter;
{
    SVArticle *article = [self representedObject];
    
    if ([[[[article page] extensibleProperties] valueForKey:@"migrateRawHTMLOnNextEdit"] boolValue])
    {
        SVMigrationHTMLWriterDOMAdaptor *result = [[SVMigrationHTMLWriterDOMAdaptor alloc] initWithOutputStringWriter:stringWriter];
        
        [result setTextDOMController:self];
        
        // Stop this happening again
        [[article page] removeExtensiblePropertyForKey:@"migrateRawHTMLOnNextEdit"];
        
        return result;
    }
    else
    {
        return [super newHTMLWritingDOMAdaptorWithOutputStringWriter:stringWriter];
    }
}

#pragma mark Moving

- (DOMNode *)nodeToMoveControllerBefore:(SVDOMController *)controller;
{
    DOMElement *element = [controller HTMLElement];
    
    DOMTreeWalker *walker = [[element ownerDocument] createTreeWalker:[self textHTMLElement]
                                                           whatToShow:DOM_SHOW_ALL
                                                               filter:nil
                                               expandEntityReferences:NO];
    [walker setCurrentNode:element];
    
    DOMNode *result = [walker ks_previousNodeIgnoringChildren];
    while (result && ![result hasSize])
    {
        result = [walker ks_previousNodeIgnoringChildren];
    }
    
    return result;
}

- (DOMNode *)nodeToMoveControllerAfter:(SVDOMController *)controller;
{
    DOMElement *element = [controller HTMLElement];
    
    DOMTreeWalker *walker = [[element ownerDocument] createTreeWalker:[self textHTMLElement]
                                                           whatToShow:DOM_SHOW_ALL
                                                               filter:nil
                                               expandEntityReferences:NO];
    [walker setCurrentNode:element];
    
    
    // Seek out the next element worth swapping with. It must:
    //  1.  Be visible on screen (i.e. element or non-whitespace text)
    //  2.  Sit below the item being dragged, to account for dragging a floated item
    DOMNode *result = [walker ks_nextNodeIgnoringChildren];
    while (result && ![result hasSize])
    {
        // Seek out next node.
        result = [walker ks_nextNodeIgnoringChildren];
    }
    
    return result;
}

- (void)moveGraphicWithDOMController:(SVDOMController *)graphicController
                          toPosition:(CGPoint)position
                               event:(NSEvent *)event;
{
    OBPRECONDITION(graphicController);
    
    SVGraphic *graphic = [graphicController representedObject];
    if ([graphic isKindOfClass:[SVCallout class]]) graphic = nil;
    
   
    // Restrict position to bounds of text
    CGPoint currentPosition = [graphicController position];
    NSRect frame = [graphicController selectionFrame];
    frame.origin.x += position.x - currentPosition.x;
    frame.origin.y += position.y - currentPosition.y;
    
    NSRect bounds = [[self textHTMLElement] boundingBox];
    
    // Expand the bottom of the box out to the end of main content
    NSRect docBounds = [[[[self HTMLElement] ownerDocument] getElementById:@"main-content"] boundingBox];
    bounds.size.height = docBounds.size.height - (NSMinY(bounds) - NSMinY(docBounds)) - 1.0f;
    
    
    if (NSMinX(frame) < NSMinX(bounds))
    {
        position.x += (NSMinX(bounds) - NSMinX(frame));
    }
    else if (NSMaxX(frame) > NSMaxX(bounds))
    {
        position.x -= (NSMaxX(frame) - NSMaxX(bounds));
    }
    
    if (NSMinY(frame) < NSMinY(bounds))
    {
        position.y += (NSMinY(bounds) - NSMinY(frame));
    }
    else if (NSMaxY(frame) > NSMaxY(bounds))
    {
        position.y -= (NSMaxY(frame) - NSMaxY(bounds));
    }
    
    
    CGPoint staticPosition = [graphicController positionIgnoringRelativePosition];
    
    if ([[graphic placement] intValue] == SVGraphicPlacementInline)
    {
        // Snap to fit current wrap. #94884
        SVTextAttachment *attachment = [graphic textAttachment];
        SVGraphicWrap wrap = [[attachment wrap] intValue];
        
        if (position.x > staticPosition.x - 10.0f &&
            position.x < staticPosition.x + 10.0f)
        {
            position.x = staticPosition.x;
        }
        else
        {
            // Set wrap to match
            if (position.x < NSMidX(bounds))
            {
                CGFloat leftEdge = NSMinX(frame) + position.x - currentPosition.x;
                if (leftEdge - NSMinX(bounds) < NSMidX(bounds) - position.x) // closer to left
                {
                    wrap = SVGraphicWrapRightSplit;
                }
                else
                {
                    wrap = SVGraphicWrapCenterSplit;
                }
            }
            else
            {
                CGFloat rightEdge = NSMaxX(frame) + position.x - currentPosition.x;
                if (NSMaxX(bounds) - rightEdge < position.x - NSMidX(bounds)) // closer to right
                {
                    wrap = SVGraphicWrapLeftSplit;
                }
                else
                {
                    wrap = SVGraphicWrapCenterSplit;
                }
            }
            
            if ([[attachment wrap] intValue] != wrap)
            {
                [attachment setWrap:[NSNumber numberWithInt:wrap]];
                [graphicController updateIfNeeded]; // push through so position can be set accurately
            }
        }
        
        
        // Show guide for choice of wrap
        NSNumber *guide;
        switch (wrap)
        {
            case SVGraphicWrapRightSplit:
            case SVGraphicWrapRight:
                guide = [NSNumber numberWithFloat:NSMinX(bounds)];
                break;
            case SVGraphicWrapCenterSplit:
                guide = [NSNumber numberWithFloat:NSMidX(bounds)];
                break;
            case SVGraphicWrapLeftSplit:
            case SVGraphicWrapLeft:
                guide = [NSNumber numberWithFloat:NSMaxX(bounds)];
                break;
            default:
                guide = nil;
        }
        [[self webEditor] setXGuide:guide yGuide:nil];
    }
    else
    {
        // Callouts only move vertically
        position.x = staticPosition.x;
    }
    
    
    // Is there space to rearrange?
    if (position.y > currentPosition.y)
    {
        DOMNode *nextNode = [self nodeToMoveControllerAfter:graphicController];
        if (nextNode)
        {
            // Is there space to make the move?
            CGFloat gap = position.y - staticPosition.y;
            NSSize size = [nextNode totalBoundingBox].size;
            
            if (gap >= 0.5 * size.height)
            {
                // Move the element
                [graphicController moveDown];
            }
        }
    }
    else if (position.y < currentPosition.y)
    {
        DOMNode *previousNode = [self nodeToMoveControllerBefore:graphicController];
        if (previousNode)
        {
            NSRect previousFrame = [previousNode boundingBox];            
            if (previousFrame.size.height <= 0.0f || NSMinY(frame) < NSMidY(previousFrame))
            {
                // Move the element
                [graphicController moveUp];
            }
        }
    }
    
    
    // Move
    [graphicController moveToPosition:position];
    
    
    
    
    
    
    
    return;
}

/*  We'll leave it up to the individual graphics
 */
- (void)moveObjectUp:(id)sender;
{
    [[self selectedItems] makeObjectsPerformSelector:@selector(moveUp)];
}
- (void)moveObjectDown:(id)sender;
{
    [[self selectedItems] makeObjectsPerformSelector:@selector(moveDown)];
}

- (void)moveItemUp:(WEKWebEditorItem *)item;
{
    WEKWebEditorView *webEditor = [self webEditor];
    WEKSelection *selection = [[webEditor webView] wek_selection];
    DOMNode *previousNode = [item previousDOMNode];
    
    while (previousNode && [webEditor shouldChangeTextInDOMRange:[item DOMRange]])
    {
        [item exchangeWithPreviousDOMNode];
        
        // Have we made a noticeable move yet?
        if ([previousNode hasSize]) break;
        
        previousNode = [item previousDOMNode];
    }
    
    [webEditor didChangeText];
    [[webEditor webView] wek_setSelection:selection];
}

- (void)moveItemDown:(WEKWebEditorItem *)item;
{
    // Save and then restore selection for if it's inside an item that's getting exchanged
    WEKWebEditorView *webEditor = [item webEditor];
    WEKSelection *selection = [[webEditor webView] wek_selection];
    DOMNode *nextNode = [item nextDOMNode];
    
    while (nextNode && [webEditor shouldChangeTextInDOMRange:[item DOMRange]])
    {
        [item exchangeWithNextDOMNode];
        
        // Have we made a noticeable move yet?
        if ([nextNode hasSize]) break;
        
        nextNode = [item nextDOMNode];
    }
    
    [webEditor didChangeText];
    
    [[webEditor webView] wek_setSelection:selection];
}

#pragma mark Drawing

- (void)drawRect:(NSRect)dirtyRect inView:(NSView *)view;
{
    if (_displayDropOutline)
    {
        [[NSColor aquaColor] set];
        NSFrameRectWithWidth([self drawingRect], 2.0f);
    }
}

- (NSRect)drawingRect;
{
    NSRect result = [super drawingRect];
    if (_displayDropOutline)
    {
        result = NSUnionRect(result, [[self dropOutlineDOMElement] boundingBox]);
    }
    
    return result;
}

#pragma mark Dragging Destination

- (DOMNode *)childForDraggingInfo:(id <NSDraggingInfo>)sender;
{
    DOMElement *element = [self textHTMLElement];
    NSPoint location = [[element documentView] convertPointFromBase:[sender draggingLocation]];
    
    
    /*  Walk through the children of text area (downwards on screen probably) until we find whose midpoint is beneath the cursor.
     */
    
    DOMTreeWalker *treeWalker = [[element ownerDocument] createTreeWalker:element
                                                               whatToShow:DOM_SHOW_ELEMENT
                                                                   filter:nil
                                                   expandEntityReferences:NO];
    
    DOMNode *result = nil;
    
    DOMNode *aNode = [treeWalker firstChild];
    while (aNode)
    {
        NSRect bounds = [aNode boundingBox];
        CGFloat mid = NSMidY(bounds);
        
        if (mid >= location.y)
        {
            // We've found our target, but dissallow it if won't cause any result
            WEKWebEditorView *webEditor = [self webEditor];
            if ([sender draggingSource] == webEditor)
            {
                for (WEKWebEditorItem *anItem in [webEditor draggedItems])
                {
                    if ([anItem isDescendantOfWebEditorItem:self])
                    {
                        while ([anItem parentWebEditorItem] != self)    // dragging image doesn't drag root
                        {
                            anItem = [anItem parentWebEditorItem];
                        }
                        
                        DOMHTMLElement *anItemElement = [anItem HTMLElement];
                        if (aNode == anItemElement || [treeWalker previousSibling] == anItemElement)
                        {
                            aNode = (id)[NSNull null];  // ugly, I know
                            break;
                        }
                    }
                }
            }
            
                  
            result = aNode;
            break;
        }
        
        aNode = [treeWalker nextSibling];
    }
    
    
    // No match was found, so insert at end. But if the end is a <BR>, use that!
    if (!result)
    {
        DOMElement *lastElement = (DOMElement *)[treeWalker currentNode];
        if ([[lastElement tagName] isEqualToString:@"BR"])
        {
            result = lastElement;
        }
    }
        
    
    // We've found probable drop point. But if that means placing below an empty paragraph/break, intention was probably to drop above it. So search backwards for real target. #93754
    DOMNode *previousElement = (result ? [treeWalker previousSibling] : [treeWalker currentNode]);
    while (previousElement)
    {
        WEKWebEditorItem *controller = [self itemForDOMNode:previousElement];
        if (!controller) // check the element's not a graphic/callout-container
        {
            NSString *text = [(DOMHTMLElement *)previousElement innerText];
            if ([text isWhitespace]) result = previousElement;
        }
        
        previousElement = [treeWalker previousSibling];
    }
    
    
    return result;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;
{
    return [self draggingUpdated:sender];
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender;
{
    // Ignore drags of inline images & text originating in our own WebView
    NSDragOperation result = NSDragOperationNone;
    
    WEKWebEditorView *webEditor = [self webEditor];
    
    id source = [sender draggingSource];
    if ([source isKindOfClass:[NSResponder class]])
    {
        if (source != webEditor && [webEditor ks_followsResponder:source]) 
        {
            return result;
        }
    }
    
    
    DOMNode *aNode = [self childForDraggingInfo:sender];
    if ((id)aNode == [NSNull null]) return NSDragOperationNone;
    
    
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
        if (source == webEditor) [self moveDragCaretToBeforeDOMNode:aNode draggingInfo:sender];
        //[[self webEditor] moveDragHighlightToDOMNode:[self dropOutlineDOMElement]];
        
        if (!_displayDropOutline)
        {
            _displayDropOutline = YES;
            [self setNeedsDisplay];
        }
    }
    else
    {
        [self setNeedsDisplay];
        [self removeDragCaret];
        //[[self webEditor] moveDragHighlightToDOMNode:nil];
    }
    
    
    return result;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender;
{
    [self removeDragCaret];
    [[self webEditor] removeDragCaret];
    //[[self webEditor] moveDragHighlightToDOMNode:nil];
}

- (BOOL)prepareForDragOperation:(id < NSDraggingInfo >)sender
{
    [self removeDragCaret];
    //[[self webEditor] moveDragHighlightToDOMNode:nil];
    [[self webEditor] removeDragCaret];
    
    return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)dragInfo;
{
    BOOL result = NO;
    
    
    // Insert serialized graphic from the pasteboard
    NSManagedObjectContext *moc = [[self representedObject] managedObjectContext];
    NSPasteboard *pasteboard = [dragInfo draggingPasteboard];
    
    NSArray *attachments = [SVTextAttachment textAttachmentsFromPasteboard:pasteboard
                                            insertIntoManagedObjectContext:moc];
    NSArray *pagelets = [attachments valueForKey:@"graphic"];
    
    
    // Fallback to generic pasteboard support
    if ([pagelets count] < 1)
    {
        pagelets = [SVGraphicFactory graphicsFromPasteboard:pasteboard
                            insertIntoManagedObjectContext:moc];
        
        // Prep them. #79398
        for (SVGraphic *aPagelet in pagelets)
        {
            [aPagelet setShowsTitle:NO];
            
            // Create text attachment for the graphic
            SVTextAttachment *textAttachment = [SVTextAttachment textAttachmentWithGraphic:aPagelet];
            
            [textAttachment setPlacement:[NSNumber numberWithInteger:SVGraphicPlacementInline]];
            [textAttachment setCausesWrap:NSBOOL(YES)];
            //[textAttachment setBody:[self representedObject]];
        }
    }
    
    
    // Insert HTML into DOM
    if ([pagelets count] && [[self webEditor] shouldChangeText:self])
    {
        DOMNode *node = [self childForDraggingInfo:dragInfo];
        //[self moveDragCaretToBeforeDOMNode:node draggingInfo:dragInfo];
        
        if (result = [self insertGraphics:pagelets beforeDOMNode:node])
        {
            // Remove source too?
            NSDragOperation mask = [dragInfo draggingSourceOperationMask];
            if ((mask & NSDragOperationMove) | (mask & NSDragOperationGeneric))
            {
                [[self webEditor] removeDraggedItems];
            }
            
            [[self webEditor] didChangeText];
        }
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
    
    
    // Stop drawing outline too
    [self setNeedsDisplay];
    _displayDropOutline = NO;
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

- (DOMElement *)dropOutlineDOMElement;
{
    return [[[self HTMLElement] ownerDocument] getElementById:@"page"];
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

- (SVTextDOMController *)newTextDOMController;
{
    SVArticleDOMController *result = [[SVArticleDOMController alloc] initWithRepresentedObject:self];
    [result setRichText:YES];
    [result setImportsGraphics:YES];
    
    return result;
}

@end


#pragma mark -


@implementation SVArticleAttachmentsController

- (NSArray *)automaticRearrangementKeyPaths;
{
    return [[super automaticRearrangementKeyPaths] arrayByAddingObject:@"placement"];
}

@end


