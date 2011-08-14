//
//  SVGraphicContainerDOMController.m
//  Sandvox
//
//  Created by Mike on 23/11/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVGraphicContainerDOMController.h"

#import "SVPasteboardItemInternal.h"
#import "SVTextAttachment.h"

#import "KSGeometry.h"

#import "DOMNode+Karelia.h"


@implementation SVGraphicContainerDOMController

#pragma mark Lifecycle

- (void)dealloc;
{
    [self setBodyHTMLElement:nil];
    OBPOSTCONDITION(!_bodyElement);
    
    [_offscreenWebViewController setDelegate:nil];
    [_offscreenWebViewController release];  // dealloc-ing mid-update
    [_offscreenContext release];
    
    [self setRepresentedObject:nil];
    
    [super dealloc];
}

#pragma mark Content

- (SVGraphic *)graphic; { return [[self representedObject] graphic]; }

#pragma mark DOM

@synthesize bodyHTMLElement = _bodyElement;

- (DOMElement *)graphicDOMElement;
{
    id result = [[[self HTMLElement] getElementsByClassName:@"graphic"] item:0];
    return result;
}

- (void)loadHTMLElementFromDocument:(DOMDocument *)document;
{
    [super loadHTMLElementFromDocument:document];
    
    // Locate body element too
    SVGraphic *graphic = [[self representedObject] graphic];
    if ([self isHTMLElementLoaded])
    {
        if ([graphic isPagelet])
        {
            DOMNodeList *elements = [[self HTMLElement] getElementsByClassName:@"pagelet-body"];
            [self setBodyHTMLElement:(DOMHTMLElement *)[elements item:0]];
        }
        else
        {
            if ([self isHTMLElementLoaded]) [self setBodyHTMLElement:[self HTMLElement]];
        }
    }
}

#pragma mark Updating

- (void)writeUpdateHTML:(SVHTMLContext *)context;
{
    [context writeGraphic:[[self representedObject] graphic]];
}

- (void)updateWrap;
{
    SVGraphic *graphic = [[self representedObject] graphic];
    
    
    // Some wrap changes actually need a full update. #94915
    BOOL writeInline = [graphic shouldWriteHTMLInline];
    NSString *oldTag = [[self HTMLElement] tagName];
    
    if ((writeInline && ![oldTag isEqualToString:@"IMG"]) ||
        (!writeInline && ![oldTag isEqualToString:@"DIV"]))
    {
        [self update];
        return;
    }
    
    
    // Will need redraw of some kind, particularly if selected
    [self setNeedsDisplay];
    
    // Update class name to get new wrap
    SVHTMLContext *context = [[SVHTMLContext alloc] initWithOutputWriter:nil];
    [graphic buildClassName:context includeWrap:YES];
    
    NSString *className = [[[context currentAttributes] attributesAsDictionary] objectForKey:@"class"];
    DOMHTMLElement *element = [self HTMLElement];
    [element setClassName:className];
    
    [context release];
    
    
    [self didUpdateWithSelector:_cmd];
}

- (void)setNeedsUpdate;
{
    id object = [self representedObject];
    if ([object respondsToSelector:@selector(requiresPageLoad)] && [object requiresPageLoad])
    {
        [[self webEditorViewController] setNeedsUpdate];
    }
    else
    {
        [super setNeedsUpdate];
    }
}

- (void)itemWillMoveToWebEditor:(WEKWebEditorView *)newWebEditor;
{
    [super itemWillMoveToWebEditor:newWebEditor];
    
    if (_offscreenWebViewController)
    {
        // If the update finishes while we're away from a web editor, there's no way to tell it so. So pretend the update has finished when removed. Likewise, pretend the update has started if added back to the editor. #131984
        if (newWebEditor)
        {
            [[newWebEditor delegate] performSelector:@selector(willUpdate)];
        }
        else
        {
            //[self stopUpdate];
            [self didUpdateWithSelector:@selector(update)];
        }
    }
}

#pragma mark Dependencies

- (void)dependenciesTracker:(KSDependenciesTracker *)tracker didObserveChange:(NSDictionary *)change forDependency:(KSObjectKeyPathPair *)dependency;
{
    // Special case where we don't want complete update
    if ([[dependency keyPath] isEqualToString:@"textAttachment.wrap"])
    {
        [self setNeedsUpdateWithSelector:@selector(updateWrap)];
    }
    else
    {
        [super dependenciesTracker:tracker didObserveChange:change forDependency:dependency];
    }
}

#pragma mark Selection & Editing

- (WEKWebEditorItem *)hitTestDOMNode:(DOMNode *)node;
{
    OBPRECONDITION(node);
    
    WEKWebEditorItem *result = nil;
    
    
    if ([self isSelectable])    // think we don't need this code branch any more
    {
        // Standard logic mostly works, but we want to ignore anything outside the graphic, instead of the HTML element
        DOMElement *testElement = [self graphicDOMElement];
        if (!testElement) testElement = [self HTMLElement];
        
        if ([node ks_isDescendantOfElement:testElement])
        {
            NSArray *children = [self childWebEditorItems];
            
            // Search for a descendant
            // Body DOM Controller will take care of looking for a single selectable child for us
            for (WEKWebEditorItem *anItem in children)
            {
                result = [anItem hitTestDOMNode:node];
                if (result) break;
            }
            
            
            if (!result && [children count] > 1) result = self;
        }
    }
    else
    {
        result = [super hitTestDOMNode:node];
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

#pragma mark Paste

- (void)paste:(id)sender;
{
    SVGraphic *graphic = [[self representedObject] graphic];
    
    if (![graphic awakeFromPasteboardItems:[[NSPasteboard generalPasteboard] sv_pasteboardItems]])
    {
        if (![[self nextResponder] tryToPerform:_cmd with:sender])
        {
            NSBeep();
        }
    }
}

#pragma mark Events

- (NSMenu *)menuForEvent:(NSEvent *)theEvent;
{
    if (![self isSelected]) return [super menuForEvent:theEvent];
    
    
    NSMenu *result = [[[NSMenu alloc] init] autorelease];
    
    [result addItemWithTitle:NSLocalizedString(@"Delete", "menu item")
                      action:@selector(delete:)
               keyEquivalent:@""];
    
    return result;
}

#pragma mark Attributed HTML

- (BOOL)writeAttributedHTML:(SVFieldEditorHTMLWriterDOMAdapator *)adaptor;
{
    SVGraphic *graphic = [[self representedObject] graphic];
    return [graphic writeAttributedHTML:adaptor webEditorItem:self];
}

#pragma mark Moving

- (NSArray *)relativePositionDOMElements;
{
    DOMElement *result = [self graphicDOMElement];
    if (result)
    {
        DOMElement *caption = [result nextSiblingOfClass:[DOMElement class]];
        return NSARRAY(result, caption);    // caption may be nil, so go ignored
    }
    else
    {
        return [super relativePositionDOMElements];
    }
}

- (KSSelectionBorder *)newSelectionBorder;
{
    KSSelectionBorder *result = [super newSelectionBorder];
    
    // Turn off handles while moving
    if ([self hasRelativePosition]) [result setEditing:YES];
    
    return result;
}

- (NSRect)frame;
{
    DOMElement *graphicElement = [self graphicDOMElement];
    if (graphicElement)
    {
        return [graphicElement boundingBox];
    }
    else
    {
        return [super frame];
    }
}

#pragma mark Resizing

- (unsigned int)resizingMask
{
    DOMElement *element = [self graphicDOMElement];
    return (element ? [self resizingMaskForDOMElement:element] : 0);
}

- (CGFloat)maxWidthForChild:(WEKWebEditorItem *)aChild
{
    // Pass on up to parent
    return [[self parentWebEditorItem] maxWidthForChild:aChild];
}

@end


#pragma mark -


@implementation WEKWebEditorItem (SVPageletDOMController)

- (SVGraphicContainerDOMController *)enclosingGraphicDOMController;
{
    id result = [self parentWebEditorItem];
    
    if (![result isKindOfClass:[SVGraphicContainerDOMController class]])
    {
        result = [result enclosingGraphicDOMController];
    }
    
    return result;
}

@end


#pragma mark -


@implementation WEKWebEditorItem (SVGraphicContainerDOMController)

- (WEKWebEditorItem <SVGraphicContainerDOMController> *)graphicContainerDOMController;
{
    id result = [self parentWebEditorItem];
    while (result && ![result conformsToProtocol:@protocol(SVGraphicContainerDOMController)])
    {
        result = [result parentWebEditorItem];
    }
    
    return result;
}

@end



