//
//  SVCallout.h
//  Sandvox
//
//  Created by Mike on 23/02/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SVGraphic.h"


@interface SVCallout : NSObject <SVComponent>
{
  @private
    NSArray *_pagelets;
}

@property(nonatomic, copy) NSArray *pagelets;

- (void)writeHTML:(SVHTMLContext *)context;

@end
