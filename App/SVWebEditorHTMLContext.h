//
//  SVWebEditorHTMLContext.h
//  Sandvox
//
//  Created by Mike on 05/11/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "SVElementInfoGatheringHTMLContext.h"

#import "SVGraphicDOMController.h"


@class SVWebEditorViewController, SVContentDOMController, SVSidebarDOMController;
@class SVContentObject, SVRichText, SVSidebar;
@class SVMediaRecord;


@interface SVWebEditorHTMLContext : SVElementInfoGatheringHTMLContext
{
  @private
    SVContentDOMController  *_rootController;
    SVDOMController         *_currentDOMController;  // weak ref
    NSIndexPath             *_DOMControllerPoints;
        
    NSMutableSet        *_media;
    NSMutableDictionary *_mediaByData;
    
    SVSidebarDOMController      *_sidebarDOMController;
}

#pragma mark Root
@property(nonatomic, retain, readonly) SVContentDOMController *rootDOMController;
- (void)addDOMController:(SVDOMController *)controller; // adds to the current controller


#pragma mark Media
- (NSSet *)media;


@end


#pragma mark -


@interface SVHTMLContext (SVEditing)

#pragma mark Sidebar

- (void)startSidebar:(SVSidebar *)sidebar; // call -endElement after writing contents


#pragma mark Current Item
- (SVDOMController *)currentDOMController;


@end


#pragma mark -


@interface SVDOMController (SVWebEditorHTMLContext)
- (void)awakeFromHTMLContext:(SVWebEditorHTMLContext *)context;
@end

