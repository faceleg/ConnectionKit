//
//  SVWebEditorHTMLContext.h
//  Sandvox
//
//  Created by Mike on 05/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVHTMLContext.h"

#import "SVGraphicDOMController.h"


@class SVWebEditorViewController, SVContentDOMController, SVSidebarDOMController;
@class SVContentObject, SVRichText, SVSidebar, SVSidebarPageletsController;
@class SVMediaRecord;


@interface SVWebEditorHTMLContext : SVHTMLContext
{
  @private
    SVContentDOMController  *_rootController;
    SVDOMController         *_currentDOMController;  // weak ref
    BOOL                    _needsToWriteElementID;
    NSInteger               _openSizeBindingControllersCount;
        
    NSMutableSet    *_media;
    
    SVSidebarDOMController      *_sidebarDOMController;
    SVSidebarPageletsController *_sidebarPageletsController;
}

#pragma mark Root
@property(nonatomic, retain, readonly) SVContentDOMController *rootDOMController;
- (void)addDOMController:(SVDOMController *)controller; // adds to the current controller


#pragma mark Media
- (NSSet *)media;


#pragma mark Text
- (void)writeText:(SVRichText *)text withDOMController:(SVDOMController *)controller;


#pragma mark Graphics
- (void)writeGraphic:(SVGraphic *)graphic withDOMController:(SVGraphicDOMController *)controller;


#pragma mark Sidebar
@property(nonatomic, retain) SVSidebarPageletsController *sidebarPageletsController;


@end


#pragma mark -


@interface SVHTMLContext (SVEditing)

#pragma mark Text Blocks
- (void)willBeginWritingHTMLTextBlock:(SVHTMLTextBlock *)textBlock;
- (void)didEndWritingHTMLTextBlock;


#pragma mark Sidebar
- (void)willBeginWritingSidebar:(SVSidebar *)sidebar; // call -didEndWritingGraphic after
// The context may provide its own controller for sidebar pagelets (pre-sorted etc.) If so, please use it.
- (SVSidebarPageletsController *)cachedSidebarPageletsController;


#pragma mark Current Item
- (SVDOMController *)currentDOMController;


@end


#pragma mark -


@interface SVDOMController (SVWebEditorHTMLContext)
- (void)awakeFromHTMLContext:(SVWebEditorHTMLContext *)context;
@end

