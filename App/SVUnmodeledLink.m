//
//  SVUnmodeledLink.m
//  Sandvox
//
//  Created by Mike on 11/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVUnmodeledLink.h"

#import "KT.h"
#import "KTPage.h"


@implementation SVUnmodeledLink

- (id)initWithAnchorElement:(DOMHTMLAnchorElement *)anchor;
{
    OBPRECONDITION(anchor);
    
    self = [self init];
    _anchor = [anchor retain];
    return self;
}

- (void)dealloc
{
    [_anchor release];
    [_moc release];
    
    [super dealloc];
}

@synthesize anchorElement = _anchor;
@synthesize managedObjectContext = _moc;

- (NSString *)targetDescription;    // normally anchor's href, but for page targets, the page title
{
    // Is there a link selected? If so, copy across its href or page name as appropriate
    NSString *result = [[self anchorElement] href];
        
    // Is it a link to a page?
    if ([result hasPrefix:kKTPageIDDesignator])
    {
        NSString *pageID = [result substringFromIndex:[kKTPageIDDesignator length]];
        KTPage *target = [KTPage pageWithUniqueID:pageID
                           inManagedObjectContext:[self managedObjectContext]];
        
        if (target)
        {
            result = [[target title] text];
            if ([result length] == 0) 
            {
                result = NSLocalizedString(@"(Empty title)",
                                           @"Indication in site outline that the page has an empty title. Distinct from untitled, which is for newly created pages.");
            }
        }
    }
    
    return result;
}

- (void)setTargetDescription:(NSString *)desc
{
    [[self anchorElement] setHref:desc];
}

@end
