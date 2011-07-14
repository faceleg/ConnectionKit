//
//  SVWebEditorHTMLContext.h
//  Sandvox
//
//  Created by Mike on 05/11/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "SVElementInfoGatheringHTMLContext.h"

#import "SVPageletDOMController.h"


@class SVWebEditorViewController, SVContentDOMController, SVSidebarDOMController;
@class SVContentObject, SVRichText, SVSidebar;
@class SVMediaRecord;


@interface SVWebEditorHTMLContext : SVElementInfoGatheringHTMLContext
{
  @private
    NSMutableSet        *_media;
    NSMutableDictionary *_mediaByData;
}

#pragma mark Media
- (NSSet *)media;


@end


#pragma mark -


@interface SVHTMLContext (SVEditing)

#pragma mark Sidebar

- (void)startSidebar:(SVSidebar *)sidebar; // call -endElement after writing contents


@end


#pragma mark -


@interface SVDOMController (SVWebEditorHTMLContext)
- (void)awakeFromHTMLContext:(SVWebEditorHTMLContext *)context;
@end

