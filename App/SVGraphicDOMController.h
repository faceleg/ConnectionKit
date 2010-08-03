//
//  SVGraphicDOMController.h
//  Sandvox
//
//  Created by Mike on 23/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVDOMController.h"
#import "SVGraphic.h"
#import "SVOffscreenWebViewController.h"


@interface SVGraphicDOMController : SVDOMController <SVOffscreenWebViewControllerDelegate>
{
  @private
    DOMHTMLElement  *_bodyElement;
    
    SVOffscreenWebViewController    *_offscreenWebViewController;
}

+ (SVGraphicDOMController *)graphicPlaceholderDOMController;

@property(nonatomic, retain) DOMHTMLElement *bodyHTMLElement;
- (DOMElement *)graphicDOMElement;
- (void)loadPlaceholderDOMElementInDocument:(DOMDocument *)document;


#pragma mark Resize
- (void)resizeToSize:(NSSize)size byMovingHandle:(SVGraphicHandle)handle;
- (NSSize)sizeByMovingHandle:(SVGraphicHandle *)handle toPoint:(NSPoint)point;


@end


#pragma mark -


// And provide a base implementation of the protocol:
@interface SVGraphic (SVDOMController) <SVDOMControllerRepresentedObject>
@end


