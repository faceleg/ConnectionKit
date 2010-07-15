//
//  SVGraphicDOMController.h
//  Sandvox
//
//  Created by Mike on 23/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVDOMController.h"
#import "SVGraphic.h"


@interface SVGraphicDOMController : SVDOMController
{
  @private
    DOMHTMLElement  *_bodyElement;
}

+ (id)DOMControllerWithGraphic:(SVGraphic *)graphic
       parentWebEditorItemToBe:(SVDOMController *)parentItem
                       context:(SVHTMLContext *)parentContext;

@property(nonatomic, retain) DOMHTMLElement *bodyHTMLElement;

@end


#pragma mark -


// And provide a base implementation of the protocol:
@interface SVGraphic (SVDOMController) <SVDOMControllerRepresentedObject>
@end


