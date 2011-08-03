//
//  SVGraphicDOMController.h
//  Sandvox
//
//  Created by Mike on 23/02/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVDOMController.h"

#import "SVAuxiliaryPageletText.h"
#import "SVGraphic.h"

#import "SVOffscreenWebViewController.h"


@class SVFieldEditorHTMLWriterDOMAdapator;


// And provide a base implementation of the protocol:
@interface SVGraphic (SVDOMController)

- (BOOL)requiresPageLoad;

- (BOOL)writeAttributedHTML:(SVFieldEditorHTMLWriterDOMAdapator *)adaptor
              webEditorItem:(WEKWebEditorItem *)item;

@end

@interface SVAuxiliaryPageletText (SVDOMController)
@end


#pragma mark -


@interface SVGraphicDOMController : SVDOMController <SVOffscreenWebViewControllerDelegate>
{
  @private
    BOOL    _drawAsDropTarget;
    
    SVOffscreenWebViewController    *_offscreenWebViewController;
    SVWebEditorHTMLContext          *_offscreenContext;
}

@end
