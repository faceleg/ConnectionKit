//
//  SVProxyHTMLContext.m
//  Sandvox
//
//  Created by Mike on 21/06/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVProxyHTMLContext.h"


@implementation SVProxyHTMLContext

- (id)initWithOutputWriter:(id <KSWriter>)output target:(SVHTMLContext *)targetContext;
{
    OBPRECONDITION(targetContext);
    
    self = [self initWithOutputWriter:output];
    
    _target = [targetContext retain];
    
    return self;
}

- (void)close;
{
    [super close];
    [_target release]; _target = nil;
}

#pragma mark Proxy methods

- (NSInteger)indentationLevel { return [_target indentationLevel]; }
- (void)setIndentationLevel:(NSInteger)level { return [_target setIndentationLevel:level]; }

- (KTPage *)page { return [_target page]; }

- (NSURL *)baseURL { return [_target baseURL]; }
- (void)setBaseURL:(NSURL *)URL { return [_target setBaseURL:URL]; }

- (BOOL)includeStyling { return [_target includeStyling]; }
- (void)setIncludeStyling:(BOOL)flag { return [_target setIncludeStyling:flag]; }

- (BOOL)liveDataFeeds { return [_target liveDataFeeds]; }
- (void)setLiveDataFeeds:(BOOL)flag { return [_target setLiveDataFeeds:flag]; }

- (NSString *)docType; { return [_target docType]; }

- (NSStringEncoding)encoding { return [_target encoding]; }

- (NSURL *)addMedia:(id <SVMedia>)media;
{
    return [_target addMedia:media];
}

- (NSURL *)addResourceAtURL:(NSURL *)fileURL preferredPath:(NSString *)uploadPath options:(NSUInteger)options;
{
    return [_target addResourceAtURL:fileURL preferredPath:uploadPath options:options];
}

@end
