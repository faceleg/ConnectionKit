//
//  SVGraphicDOMController.m
//  Sandvox
//
//  Created by Mike on 23/02/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVGraphicDOMController.h"
#import "SVGraphic.h"

#import "SVCalloutDOMController.h"
#import "SVContentDOMController.h"
#import "SVMediaRecord.h"
#import "KTPage.h"
#import "SVParagraphedHTMLWriterDOMAdaptor.h"
#import "SVPasteboardItemInternal.h"
#import "SVRawHTMLGraphic.h"
#import "SVResizableDOMController.h"
#import "SVRichTextDOMController.h"
#import "SVSidebarDOMController.h"
#import "SVTemplate.h"
#import "SVTextAttachment.h"
#import "SVWebEditorHTMLContext.h"

#import "WebEditingKit.h"
#import "WebViewEditingHelperClasses.h"

#import "DOMElement+Karelia.h"
#import "DOMNode+Karelia.h"
#import "NSColor+Karelia.h"

#import "KSGeometry.h"


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
    
    [_offscreenWebViewController setDelegate:nil];
    [_offscreenWebViewController release];  // dealloc-ing mid-update
    [_offscreenDOMControllers release];
    
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
    [super setRepresentedObject:object];
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
    if ([self isHTMLElementCreated])
    {
        if ([graphic isPagelet])
        {
            DOMNodeList *elements = [[self HTMLElement] getElementsByClassName:@"pagelet-body"];
            [self setBodyHTMLElement:(DOMHTMLElement *)[elements item:0]];
        }
        else
        {
            if ([self isHTMLElementCreated]) [self setBodyHTMLElement:[self HTMLElement]];
        }
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
    [self stopObservingDependencies];
    //[self setChildWebEditorItems:nil];
    
    
    // Setup the context
    KSStringWriter *html = [[KSStringWriter alloc] init];
    
    SVWebEditorHTMLContext *context = [[[SVWebEditorHTMLContext class] alloc]
                                       initWithOutputWriter:html inheritFromContext:[self HTMLContext]];
    
    [context writeJQueryImport];    // for any plug-ins that might depend on it
    [context writeExtraHeaders];
    
    [[context rootDOMController] setWebEditorViewController:[self webEditorViewController]];
    
    
    // Write HTML
    SVGraphic *graphic = [self representedObject];
    [context beginGraphicContainer:[[self graphicContainerDOMController] representedObject]];
    [context writeGraphic:graphic];
    [context endGraphicContainer];
    
    
    // Copy out controllers
    [_offscreenDOMControllers release];
    _offscreenDOMControllers = [[[context rootDOMController] childWebEditorItems] copy];
    
    
    // Copy top-level dependencies across to parent. #79396
    [context flush];    // you never know!
    for (KSObjectKeyPathPair *aDependency in [[context rootDOMController] dependencies])
    {
        [(SVDOMController *)[self parentWebEditorItem] addDependency:aDependency];
    }
    
    
    // Copy across data resources
    WebDataSource *dataSource = [[[[self webEditor] webView] mainFrame] dataSource];
    for (SVMedia *media in [context media])
    {
        if ([media mediaData])
        {
            [dataSource addSubresource:[media webResource]];
        }
    }
    
    
    // Bring end body code into the html
    [context writeEndBodyString];
    [context close];
    [context release];
    
    
    // Start loading DOM objects from HTML
    if (_offscreenWebViewController)
    {
        // Need to restart loading. Do so by pretending we already finished
        [self didUpdateWithSelector:_cmd];
    }
    else
    {
        _offscreenWebViewController = [[SVOffscreenWebViewController alloc] init];
        [_offscreenWebViewController setDelegate:self];
    }
    
    [_offscreenWebViewController loadHTMLFragment:[html string]];
    [html release];
}

- (void)updateWithDOMNode:(DOMNode *)node items:(NSArray *)items;
{
    // Swap in updated node. Then get the Web Editor to hook new descendant controllers up to the new nodes
    [[[self HTMLElement] parentNode] replaceChild:node oldChild:[self HTMLElement]];
    //[self setHTMLElement:nil];  // so Web Editor will endeavour to hook us up again
    
    
    // Hook up new DOM Controllers
    [[self retain] autorelease];    // replacement is likely to deallocate us
    [[self parentWebEditorItem] replaceChildWebEditorItem:self withItems:items];
    for (SVDOMController *aController in items)
    {
        [aController didUpdateWithSelector:_cmd];
    }
}

+ (DOMHTMLHeadElement *)headOfDocument:(DOMDocument *)document;
{
    if ([document respondsToSelector:@selector(head)])
    {
        return [document performSelector:@selector(head)];
    }
    else
    {
        DOMNodeList *nodes = [document getElementsByTagName:@"HEAD"];
        return (DOMHTMLHeadElement *)[nodes item:0];
    }
}

- (void)disableScriptsInNode:(DOMNode *)fragment;
{
    // I have to turn off the script nodes from actually executing
	DOMNodeIterator *it = [[fragment ownerDocument] createNodeIterator:fragment whatToShow:DOM_SHOW_ELEMENT filter:[ScriptNodeFilter sharedFilter] expandEntityReferences:NO];
	DOMHTMLScriptElement *subNode;
    
	while ((subNode = (DOMHTMLScriptElement *)[it nextNode]))
	{
		[subNode setText:@""];		/// HACKS -- clear out the <script> tags so that scripts are not executed AGAIN
		[subNode setSrc:@""];
		[subNode setType:@""];
	}
}

- (void)offscreenWebViewController:(SVOffscreenWebViewController *)controller
                       didLoadBody:(DOMHTMLElement *)loadedBody;
{
    // Pull the nodes across to the Web Editor
    DOMDocument *document = [[self HTMLElement] ownerDocument];
    DOMDocumentFragment *fragment = [document createDocumentFragment];
    DOMDocumentFragment *bodyFragment = [document createDocumentFragment];
    DOMNodeList *children = [loadedBody childNodes];
    
    BOOL importedContent = NO;
    for (int i = 0; i < [children length]; i++)
    {
        DOMNode *imported = [document importNode:[children item:i] deep:YES];
        
        // Is this supposed to be inserted at top of doc?
        if (importedContent)
        {
            [fragment appendChild:imported];
        }
        else
        {
            if ([imported isKindOfClass:[DOMElement class]])
            {
                DOMHTMLElement *element = (DOMHTMLElement *)imported;
                NSString *ID = [element idName];
                
                if ([ID isEqualToString:[[_offscreenDOMControllers objectAtIndex:0] elementIdName]])
                {
                    [fragment appendChild:imported];
                    importedContent = YES;
                    continue;
                }
            }
            
            [bodyFragment appendChild:imported];
        }
    }
    
    
    
    // I have to turn off the script nodes from actually executing
	[self disableScriptsInNode:fragment];
    [self disableScriptsInNode:bodyFragment];
    
    
    // Import headers too
    DOMDocument *offscreenDoc = [loadedBody ownerDocument];
    DOMNodeList *headNodes = [[[self class] headOfDocument:offscreenDoc] childNodes];
    DOMHTMLElement *head = [[self class] headOfDocument:document];
    
    for (int i = 0; i < [headNodes length]; i++)
    {
        DOMNode *aNode = [headNodes item:i];
        aNode = [document importNode:aNode deep:YES];
        [head appendChild:aNode];
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
    
    
    // Update
    [self updateWithDOMNode:fragment items:_offscreenDOMControllers];
    
    DOMNode *body = [(DOMHTMLDocument *)document body];
    [body insertBefore:bodyFragment refChild:[body firstChild]];
    
    
    
    // Teardown
    [_offscreenWebViewController setDelegate:nil];
    [_offscreenWebViewController release]; _offscreenWebViewController = nil;
}

- (void)updateSize;
{
    SVGraphic *graphic = [self representedObject];
    DOMElement *element = [self graphicDOMElement];
    
    [self setNeedsDisplay];
    
    NSNumber *width = [graphic containerWidth];
    if (width && ![graphic isExplicitlySized])
    {
        [[element style] setWidth:[NSString stringWithFormat:@"%@px", width]];
    }
    else
    {
        [[element style] setWidth:nil];
    }
    
    [self didUpdateWithSelector:_cmd];
    [self setNeedsDisplay];
}

- (void)updateWrap;
{
    SVGraphic *graphic = [self representedObject];
    
    
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
    [graphic buildClassName:context];
    
    NSString *className = [[[context currentElementInfo] attributesAsDictionary] objectForKey:@"class"];
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

#pragma mark Dependencies

- (void)startObservingDependencies;
{
    if (![self isObservingDependencies])
    {
        [self addObserver:self
                 forKeyPath:@"representedObject.contentWidth"
                    options:0
                    context:sGraphicSizeObservationContext];
    }
    
    [super startObservingDependencies];
}

- (void)stopObservingDependencies;
{
    if ([self isObservingDependencies])
    {
        [self removeObserver:self forKeyPath:@"representedObject.contentWidth"];
    }
    
    [super stopObservingDependencies];
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
            [self updateSize];  // needs to happen immediately
        }
        else
        {
            [self setNeedsUpdateWithSelector:@selector(updateSize)];
        }
    }
    
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

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

- (DOMElement *)selectableDOMElement;
{
    return nil;
    
    
    DOMElement *result = [self graphicDOMElement];
    if (!result) result = (id)[[[self HTMLElement] getElementsByClassName:@"pagelet-body"] item:0];
    ;
    
    
    // Seek out a better matching child which has no siblings. #93557
    DOMTreeWalker *walker = [[result ownerDocument] createTreeWalker:result
                                                          whatToShow:DOM_SHOW_ELEMENT
                                                              filter:nil
                                              expandEntityReferences:NO];
    
    DOMNode *aNode = [walker currentNode];
    while (aNode && ![walker nextSibling])
    {
        WEKWebEditorItem *controller = [super hitTestDOMNode:aNode];
        if (controller != self && [controller isSelectable])
        {
            result = nil;
            break;
        }
        
        aNode = [walker nextNode];
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

- (NSRect)selectionFrame;
{
    DOMElement *element = [self selectableDOMElement];
    if (element)
    {
        return [element boundingBox];
    }
    else
    {
        // Union together children, but only vertically once the firsy has been found
        NSRect result = NSZeroRect;
        for (WEKWebEditorItem *anItem in [self selectableTopLevelDescendants])
        {
            if (result.size.width > 0.0f)
            {
                result = [KSGeometry KSVerticallyUnionRect:result :[anItem selectionFrame]];
            }
            else
            {
                result = NSUnionRect(result, [anItem selectionFrame]);
            }
        }
        
        return result;
    }
    
    //DOMElement *element = [self graphicDOMElement];
    if (!element) element = [self HTMLElement];
    return [element boundingBox];
}

#pragma mark Paste

- (void)paste:(id)sender;
{
    SVGraphic *graphic = [self representedObject];
    
    if (![graphic awakeFromPasteboardItems:[[NSPasteboard generalPasteboard] sv_pasteboardItems]])
    {
        NSBeep();
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
    SVGraphic *graphic = [self representedObject];
    SVTextAttachment *attachment = [graphic textAttachment];
    
    
    // Is it allowed?
    if ([graphic isPagelet])
    {
        if ([adaptor importsGraphics] && [(id)adaptor allowsPagelets])
        {
            if ([[adaptor XMLWriter] openElementsCount] > 0)
            {
                return NO;
            }
        }
        else
        {
            NSLog(@"This text block does not support block graphics");
            return NO;
        }
    }
    
    
    
    
    // Go ahead and write    
    
    // Newly inserted graphics tend not to have a corresponding text attachment yet. If so, create one
    if (!attachment)
    {
        attachment = [SVTextAttachment textAttachmentWithGraphic:graphic];
        
        // Guess placement from controller hierarchy
        SVGraphicPlacement placement = ([self calloutDOMController] ?
                                        SVGraphicPlacementCallout :
                                        SVGraphicPlacementInline);
        [attachment setPlacement:[NSNumber numberWithInteger:placement]];
        
        //[attachment setWrap:[NSNumber numberWithInteger:SVGraphicWrapRightSplit]];
        [attachment setBody:[[self textDOMController] representedObject]];
    }
    
    
    // Set attachment location
    [adaptor writeTextAttachment:attachment];
    
    [[adaptor XMLWriter] flush];
    KSStringWriter *stringWriter = [adaptor valueForKeyPath:@"_output"];     // HACK!
    NSRange range = NSMakeRange([(NSString *)stringWriter length] - 1, 1);  // HACK!
    
    if (!NSEqualRanges([attachment range], range))
    {
        [attachment setRange:range];
    }
    
    
    
    
    
    return YES;
}

#pragma mark Moving

- (BOOL)moveToPosition:(CGPoint)position event:(NSEvent *)event;
{
    // See if super fancies a crack
    if ([super moveToPosition:position event:event]) return YES;
    
    
    WEKWebEditorItem <SVGraphicContainerDOMController> *dragController = [self graphicContainerDOMController];
    if ([dragController graphicContainerDOMController]) dragController = [dragController graphicContainerDOMController];
    
    [dragController moveGraphicWithDOMController:self toPosition:position event:event];
    
    
    // Starting a move turns off selection handles so needs display
    if (dragController && ![self hasRelativePosition])
    {
        [self setNeedsDisplay];
        //_moving = YES;
    }
    
    return (dragController != nil);
}

- (void)moveEnded;
{
    [super moveEnded];
    [self removeRelativePosition:YES];
}

/*  Have to re-implement because SVDOMController overrides
 */
- (CGPoint)position;
{
    NSRect rect = [self selectionFrame];
    return CGPointMake(NSMidX(rect), NSMidY(rect));
}

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

#pragma mark Resizing

- (unsigned int)resizingMask
{
    DOMElement *element = [self graphicDOMElement];
    return (element ? [self resizingMaskForDOMElement:element] : 0);
}

- (void)resizeToSize:(NSSize)size byMovingHandle:(SVGraphicHandle)handle;
{
    // Apply the change
    SVGraphic *graphic = [self representedObject];
    
    NSNumber *width = (size.width > 0 ? [NSNumber numberWithInt:size.width] : nil);
    NSNumber *height = (size.height > 0 ? [NSNumber numberWithInt:size.height] : nil);
    [graphic setWidth:width];
    [graphic setHeight:height];
    
    
    [super resizeToSize:size byMovingHandle:handle];
}


- (NSSize)constrainSize:(NSSize)size handle:(SVGraphicHandle)handle snapToFit:(BOOL)snapToFit;
{
    /*  This logic is almost identical to SVResizableDOMController, although the code here can probably be pared down to deal only with width
     */
    
    
    // If constrained proportions, apply that
    SVGraphic *graphic = [self representedObject];
    NSNumber *ratio = [graphic constrainedProportionsRatio];

    if (ratio)
    {
        BOOL resizingWidth = (handle == kSVGraphicUpperLeftHandle ||
                              handle == kSVGraphicMiddleLeftHandle ||
                              handle == kSVGraphicLowerLeftHandle ||
                              handle == kSVGraphicUpperRightHandle ||
                              handle == kSVGraphicMiddleRightHandle ||
                              handle == kSVGraphicLowerRightHandle);
        
        BOOL resizingHeight = (handle == kSVGraphicUpperLeftHandle ||
                               handle == kSVGraphicUpperMiddleHandle ||
                               handle == kSVGraphicUpperRightHandle ||
                               handle == kSVGraphicLowerLeftHandle ||
                               handle == kSVGraphicLowerMiddleHandle ||
                               handle == kSVGraphicLowerRightHandle);
        
        if (resizingWidth)
        {
            if (resizingHeight)
            {
                // Go for the biggest size of the two possibilities
                CGFloat unconstrainedRatio = size.width / size.height;
                if (unconstrainedRatio < [ratio floatValue])
                {
                    size.width = size.height * [ratio floatValue];
                }
                else
                {
                    size.height = size.width / [ratio floatValue];
                }
            }
            else
            {
                size.height = size.width / [ratio floatValue];
            }
        }
        else if (resizingHeight)
        {
            size.width = size.height * [ratio floatValue];
        }
    }
    
    
    
    if (snapToFit)
    {
        CGFloat maxWidth = [self maxWidth];
        if (size.width > maxWidth)
        {
            // Keep within max width
            // Switch over to auto-sized for simple graphics
            size.width = ([graphic isExplicitlySized] ? maxWidth : 0.0f);
            if (ratio) size.height = maxWidth / [ratio floatValue];
        }
    }
    
    
    return size;
}

- (CGFloat)maxWidth;
{
    // Base limit on design rather than the DOM
    SVGraphic *graphic = [self representedObject];
    OBASSERT(graphic);
    
    KTPage *page = [[self HTMLContext] page];
    return [graphic maxWidthOnPage:page];
}

@end


#pragma mark -


@implementation WEKWebEditorItem (SVGraphicDOMController)

- (SVGraphicDOMController *)enclosingGraphicDOMController;
{
    id result = [self parentWebEditorItem];
    
    if (![result isKindOfClass:[SVGraphicDOMController class]])
    {
        result = [result enclosingGraphicDOMController];
    }
    
    return result;
}

@end


#pragma mark -


@implementation SVGraphicBodyDOMController

#pragma mark DOM

- (void)setHTMLElement:(DOMHTMLElement *)element;
{
    [super setHTMLElement:element];
    
    if ([[self registeredDraggedTypes] count])
    {
        [element ks_addClassName:@"svx-dragging-destination"];
    }
}

- (void)loadHTMLElementFromDocument:(DOMDocument *)document
{
    [super loadHTMLElementFromDocument:document];
    
    if ([self isHTMLElementCreated])    // #103629
    {
        NSRect box = [[self HTMLElement] boundingBox];
        if (box.size.width <= 0.0f || box.size.height <= 0.0f)
        {
            // Replace with placeholder
            NSString *parsedPlaceholderHTML = [[self representedObject] parsedPlaceholderHTMLFromContext:self.HTMLContext];
            
            NSArray *children = [self childWebEditorItems];
            switch ([children count])
            {
                case 1:
                    OBASSERT([[[children objectAtIndex:0] childWebEditorItems] count] <= 1);
                    [[[children objectAtIndex:0] HTMLElement] setInnerHTML:parsedPlaceholderHTML];
                    break;
                    
                default:
                    [[self HTMLElement] setInnerHTML:parsedPlaceholderHTML];
            }
        }
    }
}

#pragma mark Selection

- (DOMElement *)selectableDOMElement;
{
    // Normally selectable, unless there's a selectable child. #96670
    BOOL selectable = YES;
    for (WEKWebEditorItem *anItem in [self childWebEditorItems])
    {
        if ([anItem isSelectable]) selectable = NO;
    }
    
    return (selectable ? [self HTMLElement] : nil);
}

- (DOMRange *)selectableDOMRange;
{
    if ([self shouldTrySelectingInline])
    {
        DOMElement *element = [self selectableDOMElement];
        DOMRange *result = [[element ownerDocument] createRange];
        [result selectNode:element];
        return result;
    }
    else
    {
        return [super selectableDOMRange];
    }
}

- (WEKWebEditorItem *)hitTestDOMNode:(DOMNode *)node;
{
    WEKWebEditorItem *result = [super hitTestDOMNode:node];
    
    
    // Pretend we're not here if only child element is selectable
    if (result == self &&
        [[self childWebEditorItems] count] == 1 &&
        [[[self childWebEditorItems] objectAtIndex:0] isSelectable])
    {
        // Seek out a better matching child which has no siblings. #93557
        DOMTreeWalker *walker = [[node ownerDocument] createTreeWalker:node
                                                            whatToShow:DOM_SHOW_ELEMENT
                                                                filter:nil
                                                expandEntityReferences:NO];
        
        if ([walker currentNode] && ![walker nextSibling]) result = nil;
    }
    
    return result;
}

- (BOOL)allowsDirectAccessToWebViewWhenSelected;
{
    // Generally, no. EXCEPT for inline, non-wrap-causing images
    BOOL result = NO;
    
    SVGraphic *image = [self representedObject];
    if ([image shouldWriteHTMLInline])
    {
        result = YES;
    }
    
    return result;
}

#pragma mark Drag & Drop

- (void) setRepresentedObject:(id)object;
{
    [super setRepresentedObject:object];
    
    // Handle whatever the object does
    [self unregisterDraggedTypes];
    NSArray *types = [object readableTypesForPasteboard:[NSPasteboard pasteboardWithName:NSDragPboard]];
    [self registerForDraggedTypes:types];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;
{
    SVGraphic *graphic = [self representedObject];
    return [graphic awakeFromPasteboardItems:[[sender draggingPasteboard] sv_pasteboardItems]];
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;
{
    _drawAsDropTarget = YES;
    [self setNeedsDisplay];
    
    return NSDragOperationCopy;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender;
{
    [self setNeedsDisplay];
    _drawAsDropTarget = NO;
}

- (BOOL) prepareForDragOperation:(id <NSDraggingInfo>)sender;
{
    [self setNeedsDisplay];
    _drawAsDropTarget = NO;
    
    return YES;
}

#pragma mark Resize

- (void) resizeToSize:(NSSize)size byMovingHandle:(SVGraphicHandle)handle;
{
    return [[self enclosingGraphicDOMController] resizeToSize:size byMovingHandle:handle];
}

- (NSSize)constrainSize:(NSSize)size handle:(SVGraphicHandle)handle snapToFit:(BOOL)snapToFit;
{
    // Body lives inside a graphic DOM controller, so use the size limit from that instead
    return [(SVDOMController *)[self parentWebEditorItem] constrainSize:size
                                                                 handle:handle
                                                              snapToFit:snapToFit];
}

- (NSSize)minSize;
{
    NSSize result = [super minSize];
    
    SVGraphic *graphic = [self representedObject];
    result.width = [graphic minWidth];

    if (result.width < MIN_GRAPHIC_LIVE_RESIZE) result.width = MIN_GRAPHIC_LIVE_RESIZE;
    return result;
}

#pragma mark Drawing

- (NSRect)dropTargetRect;
{
    NSRect result = [[self HTMLElement] boundingBox];
    
    // Movies draw using Core Animation so sit above any custom drawing of our own. Workaround by outsetting the rect
    NSString *tagName = [[self HTMLElement] tagName];
    if ([tagName isEqualToString:@"VIDEO"] || [tagName isEqualToString:@"OBJECT"])
    {
        result = NSInsetRect(result, -2.0f, -2.0f);
    }
    
    return result;
}

- (NSRect)drawingRect;
{
    NSRect result = [super drawingRect];
    
    if (_drawAsDropTarget)
    {
        result = NSUnionRect(result, [self dropTargetRect]);
    }
    
    return result;
}

- (void)drawRect:(NSRect)dirtyRect inView:(NSView *)view;
{
    [super drawRect:dirtyRect inView:view];
    
    
    // Draw outline
    if (_drawAsDropTarget)
    {
        [[NSColor aquaColor] set];
        NSFrameRectWithWidth([self dropTargetRect], 2.0f);
    }
}

- (BOOL)shouldHighlightWhileEditing; { return YES; }
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

- (BOOL)requiresPageLoad; { return NO; }

@end
