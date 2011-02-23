//
//  SVCalloutDOMController.h
//  Sandvox
//
//  Created by Mike on 28/12/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "SVDOMController.h"
#import "SVGraphicContainerDOMController.h"

#import "SVParagraphedHTMLWriterDOMAdaptor.h"


@interface SVCalloutDOMController : SVDOMController <SVGraphicContainerDOMController, KSXMLWriterDOMAdaptorDelegate>
{
  @private
    DOMElement  *_calloutContent;
}

@property(nonatomic, retain) DOMElement *calloutContentElement;

@end


#pragma mark -


@interface WEKWebEditorItem (SVCalloutDOMController)
- (SVCalloutDOMController *)calloutDOMController;
@end
