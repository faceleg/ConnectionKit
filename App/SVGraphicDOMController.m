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
#import "KTPage.h"
#import "SVParagraphedHTMLWriterDOMAdaptor.h"
#import "SVPasteboardItemInternal.h"
#import "SVRichTextDOMController.h"
#import "SVSidebarDOMController.h"
#import "SVTextAttachment.h"
#import "SVWebEditorHTMLContext.h"

#import "WebEditingKit.h"
#import "WebViewEditingHelperClasses.h"

#import "DOMNode+Karelia.h"
#import "NSColor+Karelia.h"


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
    [self startObservingDependencies];
    
    
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
    [self didUpdateWithSelector:@selector(update)];
    
    
    // Teardown
    [_offscreenWebViewController setDelegate:nil];
    [_offscreenWebViewController release]; _offscreenWebViewController = nil;
}

- (void)updateSize;
{
    SVGraphic *graphic = [self representedObject];
    DOMElement *element = [self graphicDOMElement];
    
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

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context == sGraphicSizeObservationContext)
    {
        [self setNeedsUpdateWithSelector:@selector(updateSize)];
    }
    
    // Special case where we don't want complete updaye
    else if ([keyPath isEqualToString:@"textAttachment.wrap"])
    {
        [self setNeedsUpdateWithSelector:@selector(updateWrap)];
    }
    
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
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

- (NSRect)rect;
{
    DOMElement *element = [self graphicDOMElement];
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

- (BOOL)writeAttributedHTML:(SVParagraphedHTMLWriterDOMAdaptor *)adaptor;
{
    SVGraphic *graphic = [self representedObject];
    SVTextAttachment *attachment = [graphic textAttachment];
    
    
    // Is it allowed?
    if ([graphic isPagelet])
    {
        if ([adaptor allowsPagelets])
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
        // Guess placement from controller hierarchy
        SVGraphicPlacement placement = ([self calloutDOMController] ?
                                        SVGraphicPlacementCallout :
                                        SVGraphicPlacementInline);
        
        attachment = [NSEntityDescription insertNewObjectForEntityForName:@"TextAttachment"
                                                   inManagedObjectContext:[graphic managedObjectContext]];
        [attachment setGraphic:graphic];
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
    
    
    id <SVGraphicContainerDOMController> dragController = [self graphicContainerDOMController];
    
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
    NSRect rect = [self rect];
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

- (SVSelectionBorder *)newSelectionBorder;
{
    SVSelectionBorder *result = [super newSelectionBorder];
    
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
    /*  This logic is almost identical to SVSizeBindingDOMController, although the code here can probably be pared down to deal only with width
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
        else
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

#pragma mark Selection

- (DOMElement *) selectableDOMElement;
{
    // Normally selectable, unless there's a selectable child. #96670
    BOOL selectable = YES;
    for (WEKWebEditorItem *anItem in [self childWebEditorItems])
    {
        if ([anItem isSelectable]) selectable = NO;
    }
    
    return (selectable ? [self HTMLElement] : nil);
}

- (WEKWebEditorItem *)hitTestDOMNode:(DOMNode *)node;
{
    WEKWebEditorItem *result = [super hitTestDOMNode:node];
    
    
    // Pretend we're not here if only child element is selectable
    if (result == self && [[self childWebEditorItems] count] == 1)
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
    // Fast-track; editing items cover the whole screen with darkening effect
    if ([self isEditing]) return [[[self HTMLElement] documentView] bounds];
    
    
    NSRect result = [super drawingRect];
    
    if (_drawAsDropTarget)
    {
        result = NSUnionRect(result, [self dropTargetRect]);
    }
    
    return result;
}

- (void)drawRect:(NSRect)dirtyRect inView:(NSView *)view;
{
    if ([self isEditing])
    {
        // Darken area around us
        // Clip the rect covering editing item since we want to appear normal
        CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
        CGContextSaveGState(context);
        
        CGRect unclippedRect = NSRectToCGRect([self rect]);
        
        CGContextBeginPath(context);
        CGContextAddRect(context, CGRectInfinite); 
        CGContextAddRect(context, unclippedRect);
        CGContextEOClip(context);
        
        // Draw everything else slightly darkened
        [[NSColor colorWithCalibratedWhite:0.25 alpha:0.25] set];
        NSRectFillUsingOperation(dirtyRect, NSCompositeSourceOver);
        
        CGContextRestoreGState(context);
    }
    
    
    [super drawRect:dirtyRect inView:view];
    
    
    // Draw outline
    if (_drawAsDropTarget)
    {
        [[NSColor aquaColor] set];
        NSFrameRectWithWidth([self dropTargetRect], 2.0f);
    }
}

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

@end
