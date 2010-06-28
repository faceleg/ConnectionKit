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
@dynamic shouldPreviewWhenEditing;

#pragma mark HTML

- (void)writeBody:(SVHTMLContext *)context;
{
    [context writeHTMLString:[self HTMLString]];
}

@end
