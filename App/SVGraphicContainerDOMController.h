//
//  SVGraphicContainerDOMController.h
//  Sandvox
//
//  Created by Mike on 23/11/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "SVGraphicDOMController.h"


@interface SVGraphicContainerDOMController : SVDOMController
{
  @private
    DOMHTMLElement  *_bodyElement;
        
    SVOffscreenWebViewController    *_offscreenWebViewController;
    SVWebEditorHTMLContext          *_offscreenContext;
}

+ (SVGraphicContainerDOMController *)graphicPlaceholderDOMController;

@property(nonatomic, retain) DOMHTMLElement *bodyHTMLElement;
- (DOMElement *)graphicDOMElement;


@end


#pragma mark -


@interface WEKWebEditorItem (SVPageletDOMController)
- (SVGraphicContainerDOMController *)enclosingGraphicDOMController;
@end


#pragma mark -


@protocol SVGraphicContainerDOMController <NSObject>

@optional
- (void)moveGraphicWithDOMController:(SVDOMController *)graphicController
                          toPosition:(CGPoint)position
                               event:(NSEvent *)event;

- (void)addGraphic:(SVGraphic *)graphic;


@end


@interface WEKWebEditorItem (SVGraphicContainerDOMController)
- (WEKWebEditorItem <SVGraphicContainerDOMController> *)graphicContainerDOMController;
@end