//
//  SVDesignsController.h
//  Sandvox
//
//  Created by Dan Wood on 5/7/10.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class KTDesign;

@interface SVDesignsController : NSArrayController {

	NSArray *_rangesOfGroups;
}

@property (nonatomic, retain) NSArray *rangesOfGroups;

- (KTDesign *)designWithIdentifier:(NSString *)anIdentifier;

@end
