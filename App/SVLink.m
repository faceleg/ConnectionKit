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
#import "SVImage.h"
#import "SVSiteItem.h"


@interface SVLink()
@property(nonatomic, readwrite) BOOL openInNewWindow;
@end



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

#pragma mark Deriving New Links

- (SVLink *)linkWithOpensInNewWindow:(BOOL)openInNewWindow;
{
    if ([self linkType] == SVLinkToPage)
    {
        return [SVLink linkWithSiteItem:[self page] openInNewWindow:openInNewWindow];
    }
    else
    {
        SVLink *result = [NSKeyedUnarchiver unarchiveObjectWithData:
                          [NSKeyedArchiver archivedDataWithRootObject:self]];
        
        [result setOpenInNewWindow:openInNewWindow];
        
        return result;
    }
}

#pragma mark HTML

- (void)writeStartTagToContext:(SVHTMLContext *)context image:(SVImage *)image;
{
    NSString *href = [self hrefInContext:context image:image];
    if (!href) href = @"";
    
    [context startAnchorElementWithHref:href
                                  title:nil
                                 target:([self openInNewWindow] ? @"_blank" : nil)
                                    rel:nil];
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

- (NSString *)hrefInContext:(SVHTMLContext *)context image:(SVImage *)image;
{
    NSString *result = nil;
    if ([self linkType] == SVLinkToFullSizeImage)
    {
        OBPRECONDITION(image);
        SVMedia *media = [image media];
        if (media)
        {
            NSURL *URL = [context addMedia:media];
            result = [context relativeStringFromURL:URL];
        }
    }
    else if ([self linkType] == SVLinkToPage)
    {
        SVSiteItem *page = [SVSiteItem siteItemForPreviewPath:[self URLString]
                                       inManagedObjectContext:[[context page] managedObjectContext]];
        
        if (page)
        {
            result = [context relativeStringFromURL:[context URLForPage:page]];
        }
    }
    else
    {
        result = [context relativeStringFromURL:[NSURL URLWithString:[self URLString]]];
    }
    
    // Fallback to raw string if previous failed
    if (!result)
    {
        result = [self URLString];
    }
    
    return result;
}

#pragma mark Description

- (NSString *)description;
{
    return [[super description] stringByAppendingFormat:@" %@", [self URLString]];
}

@end
