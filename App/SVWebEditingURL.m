//
//  SVWebEditingURL.m
//  Sandvox
//
//  Created by Mike on 30/07/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVWebEditingURL.h"


@implementation SVWebEditingURL

- (id)initWithString:(NSString *)URLString relativeToURL:(NSURL *)baseURL webEditorPreviewPath:(NSString *)previewPath;
{
    if (self = [super initWithString:URLString relativeToURL:baseURL])
    {
        _previewPath = [previewPath copy];
    }
    
    return self;
}

- (void)dealloc
{
    [_previewPath release];
    [super dealloc];
}

@synthesize webEditorPreviewPath = _previewPath;

@end


#pragma mark -


@implementation NSURL (SVWebEditing)

- (NSString *)webEditorPreviewPath; { return nil; }

- (NSURL *)URLWithWebEditorPreviewPath:(NSString *)previewPath;
{
    SVWebEditingURL *result = [[SVWebEditingURL alloc]
                               initWithString:[self relativeString]
                               relativeToURL:[self baseURL]
                               webEditorPreviewPath:previewPath];
    return [result autorelease];
}

@end
