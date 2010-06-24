//
//  SVDesignsController.h
//  Sandvox
//
//  Created by Dan Wood on 5/7/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SVDesignsController : NSArrayController {

	NSArray *_rangesOfGroups;
}

@property (retain) NSArray *rangesOfGroups;

@end
