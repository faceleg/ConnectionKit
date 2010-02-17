//
//  SVBodyTextHTMLContext.h
//  Sandvox
//
//  Created by Mike on 10/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVTitleBoxHTMLContext.h"


@interface SVBodyTextHTMLContext : SVTitleBoxHTMLContext
{
  @private
    SVBodyTextDOMController *_DOMController;
}

@property(nonatomic, retain) SVBodyTextDOMController *bodyTextDOMController;

@end
