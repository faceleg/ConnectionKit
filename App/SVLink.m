//
//  SVLink.m
//  Sandvox
//
//  Created by Mike on 11/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVLink.h"

#import "KT.h"
#import "SVHTMLContext.h"
#import "KTPage.h"


@implementation SVLink

#pragma mark Creating a Link

+ (id)linkWithSiteItem:(SVSiteItem *)item openInNewWindow:(BOOL)openInNewWindow;
{
    return [[[self alloc] initWithPage:item openInNewWindow:openInNewWindow] autorelease];
}

- (id)initWithURLString:(NSString *)urlString openInNewWindow:(BOOL)openInNewWindow;
{
    OBPRECONDITION(urlString);
    
    [self init];
    
    _type = SVLinkExternal;
    _URLString = [urlString copy];
    _openInNewWindow = openInNewWindow;
    
    return self;
}

- (id)initWithPage:(KTPage *)page openInNewWindow:(BOOL)openInNewWindow;
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
    
    return result;
}

#pragma mark HTML

- (void)writeStartTagToContext:(SVHTMLContext *)context;
{
    [context writeAnchorStartTagWithHref:[self URLString] title:nil target:nil rel:nil];
}

@end
