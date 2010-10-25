//
//  SVGraphicDOMController.m
//  Sandvox
//
//  Created by Mike on 23/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVGraphicDOMController.h"
#import "SVGraphic.h"

#import "SVCalloutDOMController.h"
#import "SVContentDOMController.h"
#import "SVMediaRecord.h"
#import "SVPasteboardItemInternal.h"
#import "SVRichTextDOMController.h"
#import "SVTextAttachment.h"
#import "SVWebEditorHTMLContext.h"

#import "WebEditingKit.h"
#import "WebViewEditingHelperClasses.h"

#import "DOMNode+Karelia.h"


static NSString *sGraphicSizeObservationContext = @"SVImageSizeObservation";


@interface SVGraphicPlaceholderDOMController : SVGraphicDOMController
@end


#pragma mark -


@interface DOMElement (SVGraphicDOMController)
- (DOMNodeList *)getElementsByClassName:(NSString *)name;
@end


#pragma mark -


@implementation SVGraphicDOMController

- (void)dealloc;
{
    [self setBodyHTMLElement:nil];
    OBPOSTCONDITION(!_bodyElement);
 
    [_offscreenWebViewController release];  // dealloc-ing mid-update
    
    [self setRepresentedObject:nil];
    
    [super dealloc];
}

#pragma mark Factory

+ (SVGraphicDOMController *)graphicPlaceholderDOMController;
{
    SVGraphicDOMController *result = [[[SVGraphicPlaceholderDOMController alloc] init] autorelease];
    return result;
}

#pragma mark Content

- (void)setRepresentedObject:(id)object
{
    [[self representedObject] removeObserver:self forKeyPath:@"contentWidth"];
    
    [super setRepresentedObject:object];
    
    [object addObserver:self
             forKeyPath:@"contentWidth"
                options:0
                context:sGraphicSizeObservationContext];
}

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
    SVGraphic *graphic = [self representedObject];
    if ([graphic isPagelet])
    {
        DOMNodeList *elements = [[self HTMLElement] getElementsByClassName:@"pagelet-body"];
        [self setBodyHTMLElement:(DOMHTMLElement *)[elements item:0]];
    }
    else
    {
        [self setBodyHTMLElement:[self HTMLElement]];
    }
}

- (void)loadPlaceholderDOMElementInDocument:(DOMDocument *)document;
{
    DOMElement *element = [document createElement:@"DIV"];
    [[element style] setDisplay:@"none"];
    [self setHTMLElement:(DOMHTMLElement *)element];
}

#pragma mark Updating

- (void)update;
{
    // Tear down dependencies etc.
    [self removeAllDependencies];
    [self setChildWebEditorItems:nil];
    
    
    // Write HTML
    NSMutableString *htmlString = [[NSMutableString alloc] init];
    
    SVWebEditorHTMLContext *context = [[[SVWebEditorHTMLContext class] alloc]
                                       initWithOutputWriter:htmlString inheritFromContext:[self HTMLContext]];
    
    [[context rootDOMController] setWebEditorViewController:[self webEditorViewController]];
    [context writeGraphic:[self representedObject] withDOMController:self];
    
    
    // Copy top-level dependencies across to parent. #79396
    [context flush];    // you never know!
    for (KSObjectKeyPathPair *aDependency in [[context rootDOMController] dependencies])
    {
        [(SVDOMController *)[self parentWebEditorItem] addDependency:aDependency];
    }
    
    
    // Turn observation back on. #92124
    [self setObservesDependencies:YES];
    
    
    // Copy across data resources
    WebDataSource *dataSource = [[[[self webEditor] webView] mainFrame] dataSource];
    for (id <SVMedia> aMediaRecord in [context media])
    {
        if ([aMediaRecord mediaData])
        {
            [dataSource addSubresource:[(SVMediaRecord *)aMediaRecord webResource]];
        }
    }
    
    
    // Bring end body code into the html
    [context writeEndBodyString];
    [context release];
    
    
    // Start loading DOM objects from HTML
    if (_offscreenWebViewController)
    {
        // Need to restart loading. Do so by pretending we already finished
        [self didUpdate];
    }
    else
    {
        _offscreenWebViewController = [[SVOffscreenWebViewController alloc] init];
        [_offscreenWebViewController setDelegate:self];
    }
    
    [_offscreenWebViewController loadHTMLFragment:htmlString];
    [htmlString release];
}

- (void)offscreenWebViewController:(SVOffscreenWebViewController *)controller
                       didLoadBody:(DOMHTMLElement *)loadedBody;
{
    // Pull the nodes across to the Web Editor
    DOMDocument *document = [[self HTMLElement] ownerDocument];
    DOMNode *imported = [document importNode:[loadedBody firstChild] deep:YES];
	
    
    // I have to turn off the script nodes from actually executing
	DOMNodeIterator *it = [document createNodeIterator:imported whatToShow:DOM_SHOW_ELEMENT filter:[ScriptNodeFilter sharedFilter] expandEntityReferences:NO];
	DOMHTMLScriptElement *subNode;
    
	while ((subNode = (DOMHTMLScriptElement *)[it nextNode]))
	{
		[subNode setText:@""];		/// HACKS -- clear out the <script> tags so that scripts are not executed AGAIN
		[subNode setSrc:@""];
		[subNode setType:@""];
	}
    
    
    // Are we missing a callout?
    SVGraphic *graphic = [self representedObject];
    if ([graphic isCallout] && ![self calloutDOMController])
    {
        // Create a callout stack where we are know
        SVCalloutDOMController *calloutController = [[SVCalloutDOMController alloc] initWithHTMLDocument:(DOMHTMLDocument *)document];
        [calloutController createHTMLElement];
        
        [[[self HTMLElement] parentNode] replaceChild:[calloutController HTMLElement]
                                             oldChild:[self HTMLElement]];
        
        // Then move ourself into the callout
        [[calloutController calloutContentElement] appendChild:[self HTMLElement]];
        
        [self retain];
        [[self parentWebEditorItem] replaceChildWebEditorItem:self with:calloutController];
        [calloutController addChildWebEditorItem:self];
        [calloutController release];
        [self release];
    }
    
    
    // Swap in updated node. Then get the Web Editor to hook new descendant controllers up to the new nodes
    [[[self HTMLElement] parentNode] replaceChild:imported oldChild:[self HTMLElement]];
    [self setHTMLElement:nil];  // so Web Editor will endeavour to hook us up again
    
    [[[self webEditor] delegate] webEditor:[self webEditor] // pretend we were just inserted
                                didAddItem:self];
    
    
    // Finish
    [self didUpdate];
    
    
    // Teardown
    [_offscreenWebViewController setDelegate:nil];
    [_offscreenWebViewController release]; _offscreenWebViewController = nil;
}

- (void)updateSize;
{
    SVGraphic *graphic = [self representedObject];
    DOMElement *element = [self graphicDOMElement];
    
    [[element style] setWidth:[NSString stringWithFormat:@"%@px", [graphic containerWidth]]];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context == sGraphicSizeObservationContext)
    {
        if ([[self webEditor] inLiveGraphicResize])
        {
            [self updateSize];
        }
        else
        {
            [self setNeedsUpdate];
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark State

- (DOMElement *)selectableDOMElement;
{
    DOMElement *result = [self graphicDOMElement];
    if (!result) result = [self HTMLElement];
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

#pragma mark Resizing

- (unsigned int)resizingMask
{
    DOMElement *element = [self graphicDOMElement];
    return (element ? [super resizingMask] : 0);
}

- (void)resizeToSize:(NSSize)size byMovingHandle:(SVGraphicHandle)handle;
{
    // Size calculated – now what to store?
    NSNumber *width = (size.width > 0.0f ? [NSNumber numberWithFloat:size.width] : nil);
    SVGraphic *graphic = [self representedObject];
	[graphic setWidth:width];
    
    
    [super resizeToSize:size byMovingHandle:handle];
}

- (CGFloat)maxWidth;
{
    // Whew, what a lot of questions! Now, should this drag be disallowed on account of making the DOM element bigger than its container? #84958
    DOMNode *parent = [[self HTMLElement] parentNode];
    DOMCSSStyleDeclaration *style = [[[self HTMLElement] ownerDocument] 
                                     getComputedStyle:(DOMElement *)parent
                                     pseudoElement:@""];
    
    CGFloat result = [[style width] floatValue];
    return result;
}

- (NSSize)constrainSize:(NSSize)size handle:(SVGraphicHandle)handle;
{
    CGFloat maxWidth = [self maxWidth];
    
    if (size.width > maxWidth)
    {
        SVGraphic *graphic = [self representedObject];
        size.width = ([graphic isExplicitlySized] ? maxWidth : 0.0f);
    }
    
    return size;
}

#pragma mark Drag & Drop

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;
{
    return NSDragOperationCopy;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;
{
    SVGraphic *graphic = [self representedObject];
    [graphic awakeFromPasteboardItem:[sender draggingPasteboard]];
    
    return YES;
}

- (NSArray *)registeredDraggedTypes;
{
    SVGraphic *graphic = [self representedObject];
    return [graphic readableTypesForPasteboard:[NSPasteboard pasteboardWithName:NSDragPboard]];
}

#pragma mark Drawing

- (SVSelectionBorder *)newSelectionBorder;
{
    SVSelectionBorder *result = [super newSelectionBorder];
    
    // Hide border on <OBJECT> tags etc.
    DOMElement *selectionElement = [self selectableDOMElement];
    NSString *tagName = [selectionElement tagName];
    
    if ([tagName isEqualToString:@"AUDIO"] ||
        [tagName isEqualToString:@"VIDEO"] ||
        [tagName isEqualToString:@"OBJECT"])
    {
        [result setBorderColor:nil];
    }
    return result;
}

@end


#pragma mark -


@implementation SVGraphicBodyDOMController



@end



#pragma mark -


@implementation SVGraphicPlaceholderDOMController

- (void)loadHTMLElementFromDocument:(DOMHTMLDocument *)document;
{
    [self loadPlaceholderDOMElementInDocument:document];
}

@end



#pragma mark -


@implementation SVGraphic (SVDOMController)

- (SVDOMController *)newDOMController;
{
    return [[SVGraphicDOMController alloc] initWithRepresentedObject:self];
}

- (SVDOMController *)newBodyDOMController;
{
    return [[SVGraphicBodyDOMController alloc] initWithRepresentedObject:self];
}

- (BOOL)shouldPublishEditingElementID { return NO; }
- (NSString *)elementIdName { return [NSString stringWithFormat:@"graphic-%p", self]; }

@end
