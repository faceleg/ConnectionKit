//
//  SVAttributedHTML.h
//  Sandvox
//
//  Created by Mike on 20/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class SVHTMLContext;


@interface SVAttributedHTML : NSMutableAttributedString
{
  @private
    NSMutableAttributedString *_storage;
    
}

- (void)writeHTMLToContext:(SVHTMLContext *)context;


@end
