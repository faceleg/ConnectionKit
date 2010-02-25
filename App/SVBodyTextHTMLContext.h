//
//  SVBodyTextHTMLContext.h
//  Sandvox
//
//  Created by Mike on 10/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVTitleBoxHTMLContext.h"


@class SVBodyTextDOMController;


@interface SVBodyTextHTMLContext : SVTitleBoxHTMLContext
{
  @private
    NSMutableSet    *_attachments;
    
    SVBodyTextDOMController             *_DOMController;
}

- (NSSet *)textAttachments;

@property(nonatomic, retain) SVBodyTextDOMController *bodyTextDOMController;


@end