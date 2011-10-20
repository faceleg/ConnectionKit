//
//  SVCalloutDOMController.m
//  Sandvox
//
//  Created by Mike on 28/12/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "SVCalloutDOMController.h"

#import "KTDesign.h"
#import "SVHTMLContext.h"
#import "KTImageScalingSettings.h"
#import "KTMaster.h"
#import "KTPage.h"
#import "SVRichTextDOMController.h"
#import "SVWebEditorView.h"

#import "DOMNode+Karelia.h"


@interface DOMElement (SVCalloutDOMController)
- (DOMNodeList *)getElementsByClassName:(NSString *)name;
@end


#pragma mark -


@implementation SVCalloutDOMController

#pragma mark Init & Dealloc

- (id)init;
{
    [super init];
    
    SVCallout *callout = [[SVCallout alloc] init];
    [self setRepresentedObject:callout];
    [callout release];
    
    return self;
}

- (void)dealloc
{
    [_calloutContent release];
    [super dealloc];
}

#pragma mark DOM

@synthesize calloutContentElement = _calloutContent;

- (void)loadNode;
{
    if ([self elementIdName])
    {
        return [super loadNode];
    }
    
    
    DOMHTMLDocument *document = [self HTMLDocument];
    
    // This logic is very similar to SVHTMLContext. Should be a way to bring them together
    
    DOMElement *calloutContainer = [document createElement:@"DIV"];
    [calloutContainer setAttribute:@"class" value:@"callout-container"];
    
    DOMElement *callout = [document createElement:@"DIV"];
    [callout setAttribute:@"class" value:@"callout"];
    [calloutContainer appendChild:callout];
    
    DOMElement *calloutContent = [document createElement:@"DIV"];
    [calloutContent setAttribute:@"class" value:@"callout-content"];
    [callout appendChild:calloutContent];
    
    
    [self setNode:calloutContainer];
    [self setCalloutContentElement:calloutContent];
}

- (void)nodeDidLoad
{
    [super nodeDidLoad];
    
    DOMNodeList *nodes = [[self HTMLElement] getElementsByClassName:@"callout-content"];
    [self setCalloutContentElement:(DOMElement *)[nodes item:0]];
}

#pragma mark Attributed HTML

- (BOOL)writeAttributedHTML:(SVParagraphedHTMLWriterDOMAdaptor *)writer;
{
    // Temporarily switch delegate to us for writing out children
    id delegate = [writer delegate];
    [writer setDelegate:self];
    
    @try
    {
        DOMNode *aNode = [[self calloutContentElement] firstChild];
        while (aNode)
        {
            aNode = [aNode writeTopLevelParagraph:writer];
        }
    }
    @finally
    {
        [writer setDelegate:delegate];
    }
    
    return YES;
}

- (WEKWebEditorItem *)itemForDOMNode:(DOMNode *)node;
{
    for (WEKWebEditorItem *anItem in [self childWebEditorItems])
    {
        if ([anItem HTMLElement] == node) return anItem;
    }
    
    return nil;
}

- (DOMNode *)DOMAdaptor:(SVParagraphedHTMLWriterDOMAdaptor *)writer willWriteDOMElement:(DOMElement *)element;
{
    DOMNode *result = element;
    
    // If the element is inside an DOM controller, write that out instead…
    WEKWebEditorItem *item = [self itemForDOMNode:element];
    if (item)
    {
        if ([item writeAttributedHTML:writer]) result = [element nextSibling];
    }
    
    return result;
}

#pragma mark Resizing

- (CGFloat)maxWidthForChild:(WEKWebEditorItem *)aChild;
{
    // Base limit on design rather than the DOM
    KTDesign *design = [[(KTPage *)[[self HTMLContext] page] master] design];
    KTImageScalingSettings *settings = [design imageScalingSettingsForUse:@"KTPageletMedia"];
    CGFloat result = [settings size].width;
    return result;
}

#pragma mark Moving

- (void)splitOutItemIntoSeparateCallout:(WEKWebEditorItem *)item insertBeforeRefChild:(DOMNode *)refChild;
{
    // Create a placeholder for the new callout first
    SVCallout *callout = [[SVCallout alloc] init];
    [callout setPagelets:[NSArray arrayWithObject:[item graphic]]];
    
    DOMElement *myElement = [self HTMLElement];
    SVDOMController *controller = [callout newDOMControllerWithElementIdName:nil ancestorNode:[myElement ownerDocument]];
    [controller setHTMLContext:[self HTMLContext]];
    [controller loadPlaceholderDOMElement];
    [callout release];
    
    [[self parentWebEditorItem] addChildWebEditorItem:controller];
    [[myElement parentNode] insertBefore:[controller HTMLElement] refChild:refChild];
    
    
    // Get the new callout controller to generate its HTML, recycling the existing item
    [controller addChildWebEditorItem:item];
    [controller setNeedsUpdate];
    [controller updateIfNeeded];
    [controller release];
}

/*  Normally it's enough to move ourself up or down instead of the item. But if we contain multiple graphics, have to get more cunning
 */
- (void)moveItemUp:(WEKWebEditorItem *)item;
{
    // Most of the time, want to move the whole callout
    if ([[self childWebEditorItems] count] <= 1) return [super moveItemUp:item];
    
    
    OBPRECONDITION(item);
    OBPRECONDITION([item parentWebEditorItem] == self);
    
    
    // Is there anywhere to move to within callout?
    WEKWebEditorView *webEditor = [self webEditor];
    DOMNode *previousNode = [item previousDOMNode];
    
    while (previousNode && [webEditor shouldChangeTextInDOMRange:[self DOMRange]])
    {
        [item exchangeWithPreviousDOMNode];
        
        if ([previousNode hasSize])
        {
            [webEditor didChangeText];
            return;
        }
        
        previousNode = [item previousDOMNode];
    }
    
    
    // Guess not; split the callout in two
    [self splitOutItemIntoSeparateCallout:item insertBeforeRefChild:[self HTMLElement]];
    
    // Finally it's time to really move the item down
    [[item parentWebEditorItem] moveItemUp:item];
}

- (void)moveItemDown:(WEKWebEditorItem *)item;
{
    // Most of the time, want to move the whole callout
    if ([[self childWebEditorItems] count] <= 1) return [super moveItemDown:item];
    
    
    OBPRECONDITION(item);
    OBPRECONDITION([item parentWebEditorItem] == self);
    
    
    // Is there anywhere to move to within callout?
    WEKWebEditorView *webEditor = [self webEditor];
    DOMNode *nextNode = [item nextDOMNode];
    
    while (nextNode && [webEditor shouldChangeTextInDOMRange:[self DOMRange]])
    {
        [item exchangeWithNextDOMNode];
        
        if ([nextNode hasSize])
        {
            [webEditor didChangeText];
            return;
        }
        
        nextNode = [item nextDOMNode];
    }
    
    
    // Guess not; split the callout in two
    [self splitOutItemIntoSeparateCallout:item insertBeforeRefChild:[[self HTMLElement] nextSibling]];
    
    // Finally it's time to really move the item down
    [[item parentWebEditorItem] moveItemDown:item];
}

#pragma mark Other

- (SVCalloutDOMController *)calloutDOMController;
{
    return self;
}

- (BOOL)allowsPagelets; { return YES; }

@end


#pragma mark -


@implementation WEKWebEditorItem (SVCalloutDOMController)

- (SVCalloutDOMController *)calloutDOMController; { return [[self parentWebEditorItem] calloutDOMController]; }

@end
