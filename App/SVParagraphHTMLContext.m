//
//  SVParagraphHTMLContext.m
//  Sandvox
//
//  Created by Mike on 10/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVParagraphHTMLContext.h"
#import "SVBodyParagraph.h"

#import "DOMNode+Karelia.h"


@interface SVParagraphHTMLContext ()

- (DOMElement *)changeElement:(DOMElement *)element toTagName:(NSString *)tagName;

- (DOMNode *)unlinkDOMElementBeforeWriting:(DOMElement *)element;

- (void)populateSpanElement:(DOMElement *)span
            fromFontElement:(DOMHTMLFontElement *)fontElement;

@end


#pragma mark -


@implementation SVParagraphHTMLContext

- (id)initWithParagraph:(SVBodyParagraph *)paragraph;
{
    OBPRECONDITION(paragraph);
    
    self = [self init];
    _paragraph = [paragraph retain];
    return self;
}

@synthesize paragraph = _paragraph;

- (DOMNode *)willWriteDOMElement:(DOMElement *)element
{
    DOMNode *result = element;
    NSString *tagName = [element tagName];
    
    
    
    // Ditch empty tags which aren't supposed to be
    if (![element hasChildNodes] && ![tagName isEqualToString:@"BR"])
    {
        result = [element nextSibling];
        [[element parentNode] removeChild:element];
        return [result willWriteHTMLToContext:self];
    }
    
    
        
    // Remove any tags not allowed
    if (![[self class] isTagAllowed:[element tagName]])
    {
        // Convert a bold or italic tag to <strong> or <em>
        if ([tagName isEqualToString:@"B"])
        {
            result = [self changeElement:element toTagName:@"STRONG"];
        }
        else if ([tagName isEqualToString:@"I"])
        {
            result = [self changeElement:element toTagName:@"EM"];
        }
        else if ([tagName isEqualToString:@"FONT"])
        {
            result = [self changeElement:element toTagName:@"SPAN"];
            
            [self populateSpanElement:(DOMHTMLElement *)result
                      fromFontElement:(DOMHTMLFontElement *)element];
        }
        else
        {
            result = [self unlinkDOMElementBeforeWriting:element];
        }
    }
    
    
    
    // Can't allow nested elements. e.g.    <span><span>foo</span> bar</span>   is wrong and should be simplified.
    DOMNode *firstChild = [result firstChild];
    if ([firstChild isKindOfClass:[DOMElement class]])
    {
        DOMElement *firstElement = (id)firstChild;
        if ([[firstElement tagName] isEqualToString:tagName])
        {
            [[result parentNode] insertBefore:firstElement refChild:result];
            result = firstChild;
        }
    }
    
        
    
    return result;
}

- (DOMElement *)changeElement:(DOMElement *)element toTagName:(NSString *)tagName;
{
    //WebView *webView = [[[element ownerDocument] webFrame] webView];
    
    DOMElement *result = [[element parentNode] replaceChildNode:element
                                      withElementWithTagName:tagName
                                                moveChildren:YES];
    
    return result;
}

- (DOMNode *)unlinkDOMElementBeforeWriting:(DOMElement *)element
{
    //  Called when the element hasn't fitted the whitelist. Unlinks it, and returns the correct node to write
    // Figure out the preferred next node
    DOMNode *result = [element firstChild];
    if (!result) result = [element nextSibling];
    
    // Remove non-whitelisted element
    [element unlink];
    
    // Check the new node is OK to write
    result = [result willWriteHTMLToContext:self];
    return result;
}

- (void)populateSpanElement:(DOMElement *)span
            fromFontElement:(DOMHTMLFontElement *)fontElement;
{
    [[span style] setProperty:@"font-family" value:[fontElement face] priority:@""];
    [[span style] setProperty:@"color" value:[fontElement color] priority:@""];
    // Ignoring size for now, but may have to revisit
}

#pragma mark Tag Whitelist

+ (BOOL)isTagAllowed:(NSString *)tagName;
{
    BOOL result = ([tagName isEqualToString:@"A"] ||
                   [tagName isEqualToString:@"SPAN"] ||
                   [tagName isEqualToString:@"STRONG"] ||
                   [tagName isEqualToString:@"EM"] ||
                   [tagName isEqualToString:@"BR"]);
    
    return result;
}

@end
