//
//  SVMigrationHTMLWriterDOMAdaptor.m
//  Sandvox
//
//  Created by Mike on 24/02/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVMigrationHTMLWriterDOMAdaptor.h"

#import "SVArticleDOMController.h"
#import "SVGraphicFactory.h"
#import "SVGraphicContainer.h"
#import "SVRawHTMLGraphic.h"
#import "SVTextAttachment.h"
#import "SVWebEditorHTMLContext.h"

#import "DOMNode+Karelia.h"
#import "NSString+Karelia.h"


@implementation SVMigrationHTMLWriterDOMAdaptor

- (BOOL)DOMElementContainsAWebEditorItem:(DOMElement *)element;
{
    NSArray *items = [[self textDOMController] childWebEditorItems];
    for (WEKWebEditorItem *anItem in items)
    {
        if ([[anItem HTMLElement] ks_isDescendantOfElement:element]) return YES;
    }
    
    return NO;
}

- (DOMNode *)handleInvalidDOMElement:(DOMElement *)element;
{
    // super will convert styling tags to <em> etc.
    NSString *tagName = [element tagName];
    if ([tagName isEqualToString:@"FONT"] ||    
        [tagName isEqualToString:@"I"] ||
        [tagName isEqualToString:@"B"] ||
        [tagName isEqualToString:@"TT"] ||
        [tagName hasPrefix:@"O:"] ||        // special for case like #118003
        [tagName hasPrefix:@"CENTER"])      // convert to centered paragraph
    {
        return [super handleInvalidDOMElement:element];
    }
    
    
    // If the element is invalid just because it's in the wrong location, let super take care of repositioning
    // <H1> & <H2>s are never going be legal, so convert to paragraphs
    if ([[self class] validateElement:tagName] ||
        [tagName isEqualToString:@"H1"] ||
        [tagName isEqualToString:@"H2"])
    {
        return [super handleInvalidDOMElement:element];
    }
    
    
    // <DIV>s tend to be there by accident, unless they have a class, id, or styling
    if ([tagName isEqualToString:@"DIV"])
    {
        if ([[(DOMHTMLElement *)element idName] length] == 0)
        {
            // MS Office brings along its own classname which is highly undersireable. I'm trying ot build a bit of a whitelist of what it might chuck in. #121069
            NSString *class = [element className];
            if ([class length] == 0 ||
                [class isEqualToString:@"MsoNormal"] ||
                [class isEqualToString:@"paragraph Heading_2"])
            {
                return [super handleInvalidDOMElement:element];
            }
        }
    }
    
    
    // Can't convert to raw HTML if contains an embedded image
    BOOL treatAsImageContainer = [self DOMElementContainsAWebEditorItem:element];
    if (treatAsImageContainer)
    {
        // google maps. #119961
        if ([tagName isEqualToString:@"DIV"] && [[element className] hasPrefix:@"map-"]) treatAsImageContainer = NO;
    }
    
    if (treatAsImageContainer)
    {
        return [super handleInvalidDOMElement:element];
    }
    
    
    // Ignore empty elements! #119910
    if (![tagName isEqualToString:@"SCRIPT"] &&
        [[(DOMHTMLElement *)element innerText] isWhitespace])
    {
        return [super handleInvalidDOMElement:element];
    }
    
    
    // Import as Raw HTML
    NSString *html = [KSXMLWriterDOMAdaptor outerHTMLOfDOMElement:element];
    
    SVRawHTMLGraphic *graphic = [[SVGraphicFactory rawHTMLFactory] insertNewGraphicInManagedObjectContext:
                                 [[[self textDOMController] representedObject] managedObjectContext]];
    
    [graphic setHTMLString:html];
    
    
    // Create text attachment too
    SVTextAttachment *attachment = [SVTextAttachment textAttachmentWithGraphic:graphic];
    
    BOOL causesWrap = NO;
    if ([self allowsPagelets] &&
        ![[self XMLWriter] canWriteElementInline:[tagName lowercaseString]])
    {
        causesWrap = YES;
    }
    [attachment setCausesWrap:NSBOOL(causesWrap)];
    
    SVRichText *text = [[self textDOMController] representedObject];
    if ([text attachmentsMustBeWrittenInline]) [attachment setWrap:[NSNumber numberWithInt:SVGraphicWrapFloat_1_0]];
    
    
    // Create controller for graphic and hook up to imported node
    SVInlineGraphicContainer *container = [[SVInlineGraphicContainer alloc] initWithGraphic:graphic];
    SVDOMController *controller = [container newDOMControllerWithElementIdName:nil ancestorNode:nil];
    [container release];
    
    [controller setHTMLElement:(DOMHTMLElement *)element];
    [controller awakeFromHTMLContext:[[self textDOMController] HTMLContext]];
    
    [[self textDOMController] addChildWebEditorItem:controller];
    OBASSERT([[self textDOMController] hitTestDOMNode:element] == controller);
    [controller release];
    
    
    // Generate new DOM node to match what model would normally generate
    [controller performSelector:@selector(update)];
    
    
    // Write the replacement
    OBASSERT([controller writeAttributedHTML:self]);
    
    
    return [[controller HTMLElement] nextSibling];
}

@synthesize textDOMController = _articleController;

@end
