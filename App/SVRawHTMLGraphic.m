// 
//  SVRawHTMLGraphic.m
//  Sandvox
//
//  Created by Mike on 25/06/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVRawHTMLGraphic.h"


@implementation SVRawHTMLGraphic 

@dynamic docType;
@dynamic HTMLString;
@dynamic lastValidMarkupDigest;
@dynamic shouldPreviewWhenEditing;

@class SVWebEditorViewController;

#pragma mark HTML

- (void)writeBody:(SVHTMLContext *)context;
{
    [context writeHTMLString:[self HTMLString]];
	
	// Changes to any of these properties will be a visible change
    [context addDependencyOnObject:self keyPath:@"HTMLString"];
    [context addDependencyOnObject:self keyPath:@"docType"];
    [context addDependencyOnObject:self keyPath:@"shouldPreviewWhenEditing"];
}

@end
