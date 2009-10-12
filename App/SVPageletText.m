//
//  SVContainerTextBlock.m
//  Sandvox
//
//  Created by Mike on 01/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVPageletText.h"

#import "SVWebContentItem.h"


@implementation SVPageletText

- (id)initWithDOMElement:(DOMHTMLElement *)element
{
    [super initWithDOMElement:element];
    _webContentItems = [[NSMutableSet alloc] init];
    return self;
}

- (NSArray *)contentItems
{
    // One item per image
    DOMNodeList *imageNodes = [[self DOMElement] getElementsByTagName:@"img"];
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:[imageNodes length]];
    
    for (int i = 0; i < [imageNodes length]; i++)
    {
        DOMHTMLImageElement *anImage = (DOMHTMLImageElement *)[imageNodes item:i];
        SVWebContentItem *item = [[SVWebContentItem alloc] initWithDOMElement:anImage];
        [result addObject:item];
        [item release];
    }
    
    return result;
}




/*  We need to go through the HTML creating dedicated objects for each non-text element
 */
- (void)setHTMLString:(NSString *)html
{
    [super setHTMLString:html];
    return;
    
    // Look through our section of the DOM for <img> elements
    DOMNodeList *imageNodes = [[self DOMElement] getElementsByTagName:@"img"];
    
    for (int i = 0; i < [imageNodes length]; i++)
    {
        DOMHTMLImageElement *anImage = (DOMHTMLImageElement *)[imageNodes item:i];
        SVWebContentItem *item = [[SVWebContentItem alloc] initWithDOMElement:anImage];
        [self addWebContentItem:item];
        [item release];
    }
}


- (BOOL)webEditorTextShouldInsertNode:(DOMNode *)node
                    replacingDOMRange:(DOMRange *)range
                          givenAction:(WebViewInsertAction)action
                           pasteboard:(NSPasteboard *)pasteboard;
{
    // Unlike text fields, support any drop
    return YES;
}




- (NSSet *)webContentItems { return [[_webContentItems copy] autorelease]; }

- (void)addWebContentItem:(SVWebContentItem *)item;
{
    [_webContentItems addObject:item];
}

@end
