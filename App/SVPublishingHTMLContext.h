//
//  SVPublishingHTMLContext.h
//  Sandvox
//
//  Created by Mike on 08/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVHTMLContext.h"


@protocol SVPublisher;

@interface SVPublishingHTMLContext : SVHTMLContext
{
  @private
    id <SVPublisher>    _publishingEngine;
    NSString            *_path;
    
    NSMutableString *_output;
}

- (id)initWithUploadPath:(NSString *)path
               publisher:(id <SVPublisher>)publisher;

@end
