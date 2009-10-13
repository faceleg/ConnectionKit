// 
//  SVPageletContent.m
//  Sandvox
//
//  Created by Mike on 11/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVPageletBody.h"

#import "KTPagelet.h"
#import "SVContentObject.h"


@interface SVPageletBody ()
@property(nonatomic, copy, readwrite) NSSet *contentObjects;
@end


#pragma mark -


@implementation SVPageletBody 

#pragma mark Owner

@dynamic pagelet;

#pragma mark Content

@dynamic archiveHTMLString;
@dynamic contentObjects;

- (void)setArchiveHTMLString:(NSString *)html
              contentObjects:(NSSet *)contentObjects;
{
    [self setArchiveHTMLString:html];
    [self setContentObjects:contentObjects];
}

// TODO: Write validation methods

#pragma mark Editing

- (NSString *)editingHTMLString;
{
    // Take archived HTML and insert editing HTML for content objects into it. We do this now so as to generate as close as possible an approximation to how the page will look when published. (The alternative is to load archived HTML into the DOM, and then replace individual nodes with content objects)
    return [self archiveHTMLString];
}

#pragma mark Publishing

- (NSString *)HTMLString;
{
    // FIXME: Generate real content
    return [self archiveHTMLString];
}

@end
