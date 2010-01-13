//
//  SVLink.m
//  Sandvox
//
//  Created by Mike on 11/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVLink.h"

#import "KT.h"
#import "KTPage.h"


@implementation SVLink

#pragma mark Creating a Link

- (id)initWithURLString:(NSString *)urlString openInNewWindow:(BOOL)openInNewWindow;
{
    [self init];
    
    _URLString = [urlString copy];
    _openInNewWindow = openInNewWindow;
    
    return self;
}

- (id)initWithPage:(KTAbstractPage *)page openInNewWindow:(BOOL)openInNewWindow;
{
    [self initWithURLString:[kKTPageIDDesignator stringByAppendingString:[page uniqueID]]
            openInNewWindow:openInNewWindow];
    
    _page = [page retain];
    
    return self;
}

- (void)dealloc
{
    [_URLString release];
    [_page release];
    
    [super dealloc];
}

#pragma mark Copying

- (id)copyWithZone:(NSZone *)zone
{
    return [self retain];   // immutable object
}

#pragma mark Link Properties

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
        result = [[[self page] title] text];
        if ([result length] == 0) 
        {
            result = NSLocalizedString(@"(Empty title)",
                                       @"Indication in site outline that the page has an empty title. Distinct from untitled, which is for newly created pages.");
        }
    }
    
    return result;
}

@end
