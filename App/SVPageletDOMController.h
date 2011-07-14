//
//  SVPageletDOMController.h
//  Sandvox
//
//  Created by Mike on 23/02/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVDOMController.h"

#import "SVAuxiliaryPageletText.h"
#import "SVGraphic.h"

#import "SVOffscreenWebViewController.h"


@interface SVPageletDOMController : SVDOMController <SVOffscreenWebViewControllerDelegate>
{
  @private
    DOMHTMLElement  *_bodyElement;
    
    BOOL    _observingWidth;
    
    SVOffscreenWebViewController    *_offscreenWebViewController;
    NSArray                         *_offscreenDOMControllers;
}

+ (SVPageletDOMController *)graphicPlaceholderDOMController;

@property(nonatomic, retain) DOMHTMLElement *bodyHTMLElement;
- (DOMElement *)graphicDOMElement;
- (void)loadPlaceholderDOMElementInDocument:(DOMDocument *)document;

- (void)update;
- (void)updateSize;


@end


#pragma mark -


@interface WEKWebEditorItem (SVGraphicDOMController)
- (SVPageletDOMController *)enclosingGraphicDOMController;
@end


#pragma mark -


// And provide a base implementation of the protocol:
@interface SVGraphic (SVDOMController) <SVDOMControllerRepresentedObject>
- (BOOL)requiresPageLoad;
@end

@interface SVAuxiliaryPageletText (SVDOMController) <SVDOMControllerRepresentedObject>
@end


#pragma mark -


@interface SVGraphicBodyDOMController : SVDOMController
{
@private
    BOOL    _drawAsDropTarget;
}

@end
