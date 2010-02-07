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
    
    
    // Remove any tags not allowed
    NSString *tagName = [element tagName];
    if (![[self class] isTagAllowed:[element tagName]])
    {
        // Convert a bold or italic tag to <strong> or <em>
        if ([tagName isEqualToString:@"B"])
        {
            result = [[element parentNode] replaceChildNode:element
                                     withElementWithTagName:@"STRONG"
                                               moveChildren:YES];
        }
        else if ([tagName isEqualToString:@"I"])
        {
            result = [[element parentNode] replaceChildNode:element
                                     withElementWithTagName:@"EM"
                                               moveChildren:YES];
        }
        else
        {
            // Figure out the preferred next node
            result = [element firstChild];
            if (!result) result = [element nextSibling];
            
            // Remove non-whitelisted element
            [element unlink];
            
            // Check the new node is OK to write
            result = [result willWriteHTMLToContext:self];
        }
    }
    
    return result;
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
