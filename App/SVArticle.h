//
//  SVArticle.h
//  Sandvox
//
//  Created by Mike on 27/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVRichText.h"


@class KTPage;

@interface SVArticle : SVRichText

@property (nonatomic, retain, readonly) KTPage *page;

- (NSUInteger)writeEarlyCallouts:(SVHTMLContext *)context;

#pragma mark RSS Feeds
// Uses a special escaped HTML context to pipe writing through to the feed's context
- (void)writeRSSFeedItemDescription;

@end



