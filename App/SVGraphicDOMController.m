//
//  SVGraphicDOMController.m
//  Sandvox
//
//  Created by Mike on 23/02/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVGraphicDOMController.h"
#import "SVGraphic.h"

#import "SVParagraphedHTMLWriterDOMAdaptor.h"
#import "SVPlugInDOMController.h"
#import "SVSidebarDOMController.h"
#import "SVWebEditorHTMLContext.h"
#import "WebEditingKit.h"

#import "DOMElement+Karelia.h"
#import "DOMNode+Karelia.h"
#import "NSColor+Karelia.h"


@implementation SVGraphicDOMController

#pragma mark DOM

- (void)setHTMLElement:(DOMHTMLElement *)element;
{
    [super setHTMLElement:element];
    
    if ([[self registeredDraggedTypes] count])
    {
        [element ks_addClassName:@"svx-dragging-destination"];
    }
    
    if (element)    // #103629
    {
        DOMNodeList *contents = [element getElementsByClassName:@"figure-content"];
        if ([contents length]) element = (DOMHTMLElement *)[contents item:0];
        
        if (![element ks_isVisible])
        {
            // Replace with placeholder
            NSString *parsedPlaceholderHTML = [[self representedObject] parsedPlaceholderHTMLFromContext:self.HTMLContext];
            
            NSArray *children = [self childWebEditorItems];
            switch ([children count])
            {
                case 1:
                    for (WEKWebEditorItem *anItem in children)
                    {
                    	DOMHTMLElement *child = [anItem HTMLElement];
	                    if (![[child tagName] isEqualToString:@"IMG"])  // images already have their own placeholder
	                    {
	                        [child setInnerHTML:parsedPlaceholderHTML];
                        }
                    }
                    break;
                    
                default:
                    [element setInnerHTML:parsedPlaceholderHTML];
            }
        }
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
        for (WEKWebEditorItem *anItem in [self childWebEditorItems])
        {
            if ([anItem isSelectable]) result = NO;
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

#pragma mark Resize

- (void)XresizeToSize:(NSSize)size byMovingHandle:(SVGraphicHandle)handle;
{
    return [[self enclosingGraphicDOMController] resizeToSize:size byMovingHandle:handle];
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
