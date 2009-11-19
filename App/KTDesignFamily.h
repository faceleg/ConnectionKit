//
//  KTDesignFamily.h
//  Sandvox
//
//  Created by Dan Wood on 11/19/09.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class KTDesign;

@interface KTDesignFamily : NSObject {

	NSMutableArray *designs_;
}

- (void) addDesign:(KTDesign *)aDesign;

@property (retain) NSMutableArray *designs;

@end
