//
//  SVSidebarDOMController.h
//  Sandvox
//
//  Created by Mike on 07/05/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//


#import "SVDOMController.h"


@interface SVSidebarDOMController : SVDOMController
{
  @private
    DOMElement  *_sidebarDiv;
}

@property(nonatomic, retain) DOMElement *sidebarDivElement;

@end