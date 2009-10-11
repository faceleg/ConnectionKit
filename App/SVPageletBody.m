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

#pragma mark Publishing

- (NSString *)HTMLString;
{
    // FIXME: Generate real content
    return [self archiveHTMLString];
}

@end
