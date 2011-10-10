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
#import "SVParagraphedHTMLWriterDOMAdaptor.h"
#import "SVPlugInDOMController.h"
#import "SVSidebarDOMController.h"
#import "SVWebEditorUpdatesHTMLContext.h"
#import "WebEditingKit.h"
#import "SVWebEditorViewController.h"
#import "WebViewEditingHelperClasses.h"

#import "DOMElement+Karelia.h"
#import "DOMNode+Karelia.h"
#import "NSColor+Karelia.h"


@implementation SVGraphicDOMController

#pragma mark DOM

- (BOOL)elementIsPlaceholder:(DOMElement *)element;
{
    return (![element firstElementChild] && ![[element tagName] isEqualToString:@"IMG"]);
}

- (void)setNode:(DOMHTMLElement *)element;
{
    [super setNode:element];
    
    if ([[self registeredDraggedTypes] count])
    {
        [element ks_addClassName:@"svx-dragging-destination"];
    }
    
    if (element)    // #103629
    {
        DOMNodeList *contents = [element getElementsByClassName:@"figure-content"];
        if ([contents length]) element = (DOMHTMLElement *)[contents item:0];
        
        if ([self elementIsPlaceholder:element])
        {
            // Replace with placeholder
            NSString *parsedPlaceholderHTML = [[self representedObject] parsedPlaceholderHTMLFromContext:self.HTMLContext];
            
            NSArray *children = [self childWebEditorItems];
            switch ([children count])
            {
                case 1:
                    for (WEKWebEditorItem *anItem in children)
                    {
                    	DOMElement *child = [anItem HTMLElement];
	                    if (![[child tagName] isEqualToString:@"IMG"])  // images already have their own placeholder
	                    {
	                        [(DOMHTMLElement *)child setInnerHTML:parsedPlaceholderHTML];
                        }
                    }
                    break;
                    
                default:
                    [element setInnerHTML:parsedPlaceholderHTML];
            }
        }
    }
}

- (void)XloadNode;
{
    [super loadNode];
    
    // In the case of #143323, graphics inside a <NOSCRIPT> tag can't be loaded, so fallback to generating a placeholder
    if (![self isNodeLoaded])
    {
        [self loadPlaceholderDOMElement];
    }
}

- (void)itemDidMoveToWebEditor;
{
    [super itemDidMoveToWebEditor];
    
    // Try to load it, since in an update this may be the only chance available.
    if ([self webEditor]) [self HTMLElement];
}

#pragma mark Selection

- (BOOL)isSelectable;
{
    // Normally selectable, unless there's a selectable child. #96670
    BOOL result = [super isSelectable];
    if (result)
    {
        if ([[self childWebEditorItems] count] == 1 &&
            [[[self childWebEditorItems] objectAtIndex:0] isSelectable] &&
            ![[self parentWebEditorItem] isKindOfClass:[SVGraphicDOMController class]])
        {
            result = NO;
        }
    }
    
    return result;
}

- (DOMRange *)selectableDOMRange;
{
    if ([self shouldTrySelectingInline])
    {
        DOMElement *element = [self HTMLElement];
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
    // Plug-ins might run scripts that remove elements from the DOM tree, temporarily or permanently. Thus, be more thorough and check out all descendants. Not a significant performance hit, since there's a containing DOM controller to get past first.
    
    WEKWebEditorItem *result = nil;
    for (WEKWebEditorItem *anItem in [self childWebEditorItems])
    {
        result = [anItem hitTestDOMNode:node];
        if (result) break;
    }
    
    if (!result && [node ks_isDescendantOfElement:[self HTMLElement]]) result = self;
    
    
    // Pretend we're not here if not selectable, since child takes over that responsibility
    if (result == self && ![self isSelectable])
    {
        result = nil;
    }
    
    return result;
}

- (BOOL)allowsDirectAccessToWebViewWhenSelected;
{
    // Generally, no. EXCEPT for inline, non-wrap-causing images
    BOOL result = NO;
    
    SVGraphic *image = [self representedObject];
    if ([image displayInline])
    {
        result = YES;
    }
    
    return result;
}

#pragma mark Text Editing

- (BOOL)writeAttributedHTML:(SVFieldEditorHTMLWriterDOMAdapator *)writer
{
    return [[self representedObject] writeAttributedHTML:writer webEditorItem:self];
}

- (SVGraphic *)graphic; { return [self representedObject]; }

#pragma mark Drag & Drop

- (void)setRepresentedObject:(id)object;
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

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;
{
    [self setNeedsDisplay];
    _drawAsDropTarget = NO;
    
    return YES;
}

#pragma mark Updating

- (void)updateWithDOMNode:(DOMNode *)node items:(NSArray *)items;
{
    // Swap in updated node and correct items to point at their new ancestorNode
    DOMNode *parentNode = [[self HTMLElement] parentNode];
    
    [parentNode replaceChild:node oldChild:[self HTMLElement]];
    
    for (WEKWebEditorItem *anItem in items)
    {
        [anItem setAncestorNode:parentNode recursive:YES];
    }
    
    
    
    SVWebEditorViewController *viewController = [self webEditorViewController];
    [viewController willUpdate];    // wrap the replacement like this so doesn't think update finished too early
    {
        [self didUpdateWithSelector:@selector(update)];
        [[self retain] autorelease];    // replacement is likely to deallocate us
        [[self parentWebEditorItem] replaceChildWebEditorItem:self withItems:items];
    }
    [viewController didUpdate];
}

- (void)update;
{
    // Tear down dependencies etc.
    [self stopObservingDependencies];
    //[self setChildWebEditorItems:nil];
    
    
    // Setup the context
    KSStringWriter *html = [[[KSStringWriter alloc] init] autorelease];
    DOMHTMLDocument *doc = (DOMHTMLDocument *)[[self HTMLElement] ownerDocument];
    
    SVWebEditorHTMLContext *context = [[[SVWebEditorUpdatesHTMLContext class] alloc]
                                       initWithDOMDocument:doc
                                       outputWriter:html
                                       inheritFromContext:[self HTMLContext]];
    
    [context writeJQueryImport];    // for any plug-ins that might depend on it
    [context writeExtraHeaders];
    
    //[[context rootDOMController] setWebEditorViewController:[self webEditorViewController]];
    
    
    // Write HTML
    id <SVComponent> container = [[self parentWebEditorItem] representedObject];   // rarely nil, but sometimes is. #116816
    
    if (container) [context beginGraphicContainer:container];
    [context writeGraphic:[self representedObject]];
    if (container) [context endGraphicContainer];
    
    
    // Copy out controllers
    [_offscreenContext release];
    _offscreenContext = [context retain];
    
    
    // Copy top-level dependencies across to parent. #79396
    [context flush];    // you never know!
    [[self mutableSetValueForKeyPath:@"parentWebEditorItem.dependencies"] unionSet:[[context rootElement] dependencies]];
    
    
    // Copy across data resources
    WebDataSource *dataSource = [[[[self webEditor] webView] mainFrame] dataSource];
    for (SVMedia *media in [context media])
    {
        if ([media webResource])
        {
            [dataSource addSubresource:[media webResource]];
        }
    }
    
    
    // Bring end body code into the html
    [context writeEndBodyString];
    [context close];
    
    
	DOMDocumentFragment *fragment = [doc createDocumentFragmentWithMarkupString:[html string] baseURL:nil];
    [context release];
    
    
    if (fragment)
    {
        SVContentDOMController *rootController = [[SVContentDOMController alloc]
                                                  initWithWebEditorHTMLContext:_offscreenContext
                                                  node:fragment];
        DOMElement *anElement = [fragment firstChildOfClass:[DOMElement class]];
        while (anElement)
        {
            if ([[anElement getElementsByTagName:@"SCRIPT"] length]) break; // deliberately ignoring top-level scripts
            
            NSString *ID = [[[rootController childWebEditorItems] objectAtIndex:0] elementIdName];
            if ([ID isEqualToString:[anElement getAttribute:@"id"]])
            {
                // Search for any following scripts
                if ([anElement nextElementSibling]) break;
                
                // No scripts, so can update directly
                [self updateWithDOMNode:anElement items:[rootController childWebEditorItems]];
                
                [rootController release];
                [_offscreenContext release]; _offscreenContext = nil;
                return;
            }
            
            anElement = [anElement nextElementSibling];
        }
        
        [rootController release];
    }
    
    
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

- (void)stopUpdate;
{
    [_offscreenWebViewController setDelegate:nil];
    [_offscreenWebViewController release]; _offscreenWebViewController = nil;
    [_offscreenContext release]; _offscreenContext = nil;
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
        DOMNode *node = [children item:i];
        
        // I'd like to try adopting the node, then fallback to import, as described in http://www.w3.org/TR/DOM-Level-3-Core/core.html#Document3-adoptNode
        // However, in practice adopted nodes don't seem to notice the CSS rules that apply to them. So instead importing, and falling back to adoption if that throws an exception. #135186
        DOMNode *imported;
        @try
        {
            imported = [document importNode:node deep:YES];
        }
        @catch (NSException *exception)
        {
            NSString *name = [exception name];
            if ([name isEqualToString:DOMException])
            {
                imported = [document adoptNode:node];
            }
            else
            {
                @throw exception;
            }
        }
        
        
        if (!imported)
        {
            // TODO:
            // As noted at http://www.w3.org/TR/DOM-Level-3-Core/core.html#Core-Document-importNode this could raise an exception, which we should probably catch and handle in some fashion
            imported = [document importNode:node deep:YES];
        }
        
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
                if (ID)
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
        SVCalloutDOMController *calloutController = [[SVCalloutDOMController alloc]
                                                     initWithIdName:nil
                                                     ancestorNode:[[self HTMLElement] ownerDocument]];
        
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
    SVContentDOMController *rootController = [[SVContentDOMController alloc]
                                              initWithWebEditorHTMLContext:_offscreenContext
                                              node:fragment];
    
    [self updateWithDOMNode:fragment items:[rootController childWebEditorItems]];
    [rootController release];
    
    
    DOMNode *body = [(DOMHTMLDocument *)document body];
    [body insertBefore:bodyFragment refChild:[body firstChild]];
    
    
    
    // Teardown
    [self stopUpdate];
}

#pragma mark Resize

- (void)XresizeToSize:(NSSize)size byMovingHandle:(SVGraphicHandle)handle;
{
    return [[self enclosingGraphicDOMController] resizeToSize:size byMovingHandle:handle];
}

- (CGFloat)maxWidthForChild:(WEKWebEditorItem *)aChild;
{
    // Carry on up
    return [[self parentWebEditorItem] maxWidthForChild:aChild];
}

- (CGFloat)constrainToMaxWidth:(CGFloat)maxWidth;
{
    return ([[self representedObject] isExplicitlySized] ? [super constrainToMaxWidth:maxWidth] : 0.0f);
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
    // Figure best element to draw
    DOMElement *element = nil;
    if (![self isSelectable])
    {
        for (WEKWebEditorItem *anItem in [self childWebEditorItems])
        {
            if ([anItem isSelectable])
            {
                element = [anItem HTMLElement];
                break;
            }
        }
    }
    if (!element) element = [self HTMLElement];
    
    NSRect result = [element boundingBox];
    
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


#import "SVCalloutDOMController.h"
#import "SVRichTextDOMController.h"
#import "SVTextAttachment.h"


@implementation SVGraphic (SVDOMController)

- (BOOL)writeAttributedHTML:(SVFieldEditorHTMLWriterDOMAdapator *)adaptor
              webEditorItem:(WEKWebEditorItem *)item;
{
    SVTextAttachment *attachment = [self textAttachment];
    
    
    // Is it allowed?
    if ([self isPagelet])
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
        attachment = [SVTextAttachment textAttachmentWithGraphic:self];
        
        // Guess placement from controller hierarchy
        SVGraphicPlacement placement = ([item calloutDOMController] ?
                                        SVGraphicPlacementCallout :
                                        SVGraphicPlacementInline);
        [attachment setPlacement:[NSNumber numberWithInteger:placement]];
        
        //[attachment setWrap:[NSNumber numberWithInteger:SVGraphicWrapRightSplit]];
        [attachment setBody:[(SVRichTextDOMController *)[item textDOMController] richTextStorage]];
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

- (BOOL)requiresPageLoad; { return NO; }

@end


#pragma mark -


@implementation WEKWebEditorItem (SVGraphicDOMController)

- (SVGraphic *)graphic; { return nil; }

@end
