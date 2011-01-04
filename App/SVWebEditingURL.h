//
//  SVWebEditingURL.h
//  Sandvox
//
//  Created by Mike on 30/07/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SVWebEditingURL : NSURL
{
  @private
    NSString    *_previewPath;
}

- (id)initWithString:(NSString *)URLString relativeToURL:(NSURL *)baseURL webEditorPreviewPath:(NSString *)previewPath;

@property(nonatomic, copy, readonly) NSString *webEditorPreviewPath;

@end


#pragma mark -


@interface NSURL (SVWebEditing)
- (NSString *)webEditorPreviewPath;
- (NSURL *)URLWithWebEditorPreviewPath:(NSString *)previewPath;
@end