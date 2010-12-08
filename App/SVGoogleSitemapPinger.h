//
//  SVGoogleSitemapPinger.h
//  Sandvox
//
//  Created by Terrence Talbot on 12/7/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SVPublisher.h"

@interface SVGoogleSitemapPinger : NSObject <SVPublishedObject>
{
    NSDate *_datePublished;
}

@property(retain) NSDate *datePublished;

@end
