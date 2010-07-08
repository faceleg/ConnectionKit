// 
//  SVRawHTMLGraphic.m
//  Sandvox
//
//  Created by Mike on 25/06/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVRawHTMLGraphic.h"

#import "SVHTMLContext.h"
#import "SVTemplate.h"


@implementation SVRawHTMLGraphic 

@dynamic docType;
@dynamic HTMLString;
@dynamic lastValidMarkupDigest;
@dynamic shouldPreviewWhenEditing;

#pragma mark HTML

- (void)writeBody:(SVHTMLContext *)context;
{
    // Usually, just write out the code and be done
    if (![[self shouldPreviewWhenEditing] boolValue] && ![context shouldWriteServerSideScripts])
    {
        [context writeHTMLString:[[[self class] placeholderTemplate] templateString]];
    }
    else
    {
        [context writeHTMLString:[self HTMLString]];
        [context addDependencyOnObject:self keyPath:@"HTMLString"];
    }
	
	// Changes to any of these properties will be a visible change
    [context addDependencyOnObject:self keyPath:@"docType"];
    [context addDependencyOnObject:self keyPath:@"shouldPreviewWhenEditing"];
}

+ (SVTemplate *)placeholderTemplate;
{
    static SVTemplate *result;
    if (!result)
    {
        result = [[SVTemplate templateNamed:@"RawHTMLPlaceholder.html"] retain];
    }
    
    return result;
}

@end
