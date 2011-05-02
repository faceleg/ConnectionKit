//
//  SVGoogleSitemapPinger.h
//  Sandvox
//
//  Created by Terrence Talbot on 12/7/10.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SVPublisher.h"

@interface SVGoogleSitemapPinger : NSObject <SVPublishedObject>
{
    NSDate *_datePublished;
}

@property (nonatomic, retain) NSDate *datePublished;

@end
