//
//  SVPageThumbnailHTMLContext.h
//  Sandvox
//
//  Created by Mike on 26/01/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

//  Specialised context that the Page Inspector uses to figure out thumbnail that's in use. That way it can follow the exact same logic as HTML generation.


#import "SVHTMLContext.h"


@class KSObjectKeyPathPair, SVMedia;
@protocol SVPageThumbnailHTMLContextDelegate;


@interface SVPageThumbnailHTMLContext : SVHTMLContext
{
  @private
    id <SVPageThumbnailHTMLContextDelegate> _delegate;
}

@property(nonatomic, assign) id <SVPageThumbnailHTMLContextDelegate> delegate;
@end


@protocol SVPageThumbnailHTMLContextDelegate

- (void)pageThumbnailHTMLContext:(SVPageThumbnailHTMLContext *)context
                     didAddMedia:(SVMedia *)media;

- (void)pageThumbnailHTMLContext:(SVPageThumbnailHTMLContext *)context
                   addDependency:(KSObjectKeyPathPair *)dependency;

@end
