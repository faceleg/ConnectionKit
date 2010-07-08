// 
//  SVRawHTMLGraphic.m
//  Sandvox
//
//  Created by Mike on 25/06/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVRawHTMLGraphic.h"

#import "SVHTMLContext.h"


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
        [context writeHTMLString:@"<span style=\"background:rgb(0,127,255); -webkit-border-radius:3px; padding:2px 5px; color:white; font-size:80%;\">HTML</span>"];
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

@end
