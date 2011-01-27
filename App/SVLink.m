//
//  SVLink.m
//  Sandvox
//
//  Created by Mike on 11/01/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVLink.h"

#import "KT.h"
#import "SVHTMLContext.h"
#import "SVSiteItem.h"


@implementation SVLink

#pragma mark Creating a Link

+ (id)linkWithURLString:(NSString *)urlString openInNewWindow:(BOOL)openInNewWindow;
{
    return [[[self alloc] initWithURLString:urlString openInNewWindow:openInNewWindow] autorelease];
}

+ (id)linkWithSiteItem:(SVSiteItem *)item openInNewWindow:(BOOL)openInNewWindow;
{
    return [[[self alloc] initWithPage:item openInNewWindow:openInNewWindow] autorelease];
}

- (id)initWithURLString:(NSString *)urlString openInNewWindow:(BOOL)openInNewWindow;
{
    OBPRECONDITION(urlString);
    
    [self init];
    
    _type = ([urlString hasPrefix:@"mailto:"] ? SVLinkEmail : SVLinkExternal);
    _URLString = [urlString copy];
    _openInNewWindow = openInNewWindow;
    
    return self;
}

- (id)initWithPage:(SVSiteItem *)page openInNewWindow:(BOOL)openInNewWindow;
{
    OBPRECONDITION(page);
    
    [self initWithURLString:[kKTPageIDDesignator stringByAppendingString:[page uniqueID]]
            openInNewWindow:openInNewWindow];
    
    _type = SVLinkToPage;
    _page = [page retain];
    
    return self;
}

- (id)initLinkToFullSizeImageOpensInNewWindow:(BOOL)openInNewWindow;
{
    [self init];
    
    _type = SVLinkToFullSizeImage;
    _openInNewWindow = openInNewWindow;
    
    return self;
}

- (void)dealloc
{
    [_URLString release];
    [_page release];
    
    [super dealloc];
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder
{
    [self init];
    
    _type = [aDecoder decodeIntegerForKey:@"type"];
    _URLString = [[aDecoder decodeObjectForKey:@"URLString"] copy];
    _openInNewWindow = [aDecoder decodeBoolForKey:@"openInNewWindow"];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:[self page] forKey:@"page"];   // should fail if page is non-nil
    [aCoder encodeInteger:[self linkType] forKey:@"type"];
    [aCoder encodeObject:[self URLString] forKey:@"URLString"];
    [aCoder encodeBool:[self openInNewWindow] forKey:@"openInNewWindow"];
}

#pragma mark Copying

- (id)copyWithZone:(NSZone *)zone
{
    return [self retain];   // immutable object
}

#pragma mark Link Properties

@synthesize linkType = _type;
@synthesize URLString = _URLString;
@synthesize page = _page;
@synthesize openInNewWindow = _openInNewWindow;

- (NSString *)targetDescription;    // normally anchor's href, but for page targets, the page title
{
    // Is there a link selected? If so, copy across its href or page name as appropriate
    NSString *result = [self URLString];
        
    // Is it a link to a page?
    if ([self page])
    {
        result = [[self page] title];
        if ([result length] == 0) 
        {
            result = NSLocalizedString(@"(Empty title)",
                                       @"Indication in site outline that the page has an empty title. Distinct from untitled, which is for newly created pages.");
        }
    }
    else if ([self linkType] == SVLinkEmail)
    {
        NSURL *url = [[NSURL alloc] initWithString:result];
        result = [url resourceSpecifier];
        [url release];
    }
    
    return result;
}

#pragma mark HTML

- (void)writeStartTagToContext:(SVHTMLContext *)context;
{
    [context startAnchorElementWithHref:[self URLString] title:nil target:nil rel:nil];
}

- (DOMElement *)createDOMElementInDocument:(DOMDocument *)document;
{
    // Create our own link so it has correct text content. #104879
    DOMHTMLAnchorElement *result = (DOMHTMLAnchorElement *)[document createElement:@"A"];
    [result setHref:[self URLString]];
    
    DOMText *text = [document createTextNode:[self targetDescription]];
    [result appendChild:text];
    
    return result;
}

#pragma mark Description

- (NSString *)description;
{
    return [[super description] stringByAppendingFormat:@" %@", [self URLString]];
}

@end
