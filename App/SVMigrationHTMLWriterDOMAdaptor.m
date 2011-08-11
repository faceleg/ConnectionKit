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
#import "SVRawHTMLGraphic.h"
#import "SVTextAttachment.h"
#import "SVWebEditorHTMLContext.h"

#import "DOMNode+Karelia.h"
#import "NSString+Karelia.h"


@implementation SVMigrationHTMLWriterDOMAdaptor

- (BOOL)DOMElementContainsAnInDocumentImage:(DOMElement *)element;
{
    DOMNodeList *images = [element getElementsByTagName:@"IMG"];
    NSUInteger i, count = [images length];
    
    for (i = 0; i < count; i++)
    {
        DOMHTMLImageElement *anImage = (DOMHTMLImageElement *)[images item:i];
        if ([[anImage absoluteImageURL] isFileURL]) return YES;
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
    
    
    // <DIV>s tend to be there by accident, unless they have an ID
    if ([tagName isEqualToString:@"DIV"])
    {
        NSString *divID = [(DOMHTMLElement *)element idName];
        if ([divID length] == 0)
        {
            // MS Office brings along its own classname which is highly undesirable. I'm trying to build a bit of a whitelist of what it might chuck in. #121069
            // Custom classes from PayPal have a habit of leaking into every following paragraph too. #137833
            NSString *class = [element className];
            if ([class length] == 0 ||
                [class isEqualToString:@"MsoNormal"] ||
                [class isEqualToString:@"paragraph Heading_2"] ||
                [class isEqualToString:@"product"])
            {
                return [super handleInvalidDOMElement:element];
            }
        }
        else if ([[element ownerDocument] getElementById:divID] != element)
        {
            // Some people have somehow copied Sandvox markup inside the main text, making IDs conflict. Convert those to regular text. #137745
            return [super handleInvalidDOMElement:element];
        }
    }
    
    
    // Can't convert to raw HTML if contains an embedded image
    BOOL treatAsImageContainer = [self DOMElementContainsAnInDocumentImage:element];
    
    
    if (treatAsImageContainer)
    {
        return [super handleInvalidDOMElement:element];
    }
    
    
    // Ignore most empty elements! #119910
    if (![tagName isEqualToString:@"SCRIPT"] &&
        ![tagName isEqualToString:@"IFRAME"] &&
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
    
    SVRichText *container = [[self textDOMController] representedObject];
    if ([container attachmentsMustBeWrittenInline]) [attachment setWrap:[NSNumber numberWithInt:SVGraphicWrapFloat_1_0]];
    
    
    // Create controller for graphic and hook up to imported node
    SVDOMController *controller = [graphic newDOMController];
    [controller awakeFromHTMLContext:[[self textDOMController] HTMLContext]];
    [controller setHTMLElement:(DOMHTMLElement *)element];
    
    [[self textDOMController] addChildWebEditorItem:controller];
    OBASSERT([[self textDOMController] hitTestDOMNode:element] == controller);
    [controller release];
    
    
    // Generate new DOM node to match what model would normally generate
    DOMNode *result = [[controller HTMLElement] nextSibling];    // get in before update, in case it's synchronous!
    [controller setNeedsUpdate];
    [controller updateIfNeeded];
    
    
    // Write the replacement
    OBASSERT([controller writeAttributedHTML:self]);
    
    
    return result;
}

@synthesize textDOMController = _articleController;

@end
