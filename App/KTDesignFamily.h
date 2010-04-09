//
//  KTDesignFamily.h
//  Sandvox
//
//  Created by Dan Wood on 11/19/09.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTDesign.h"		// for fake protocol


@class KTDesign;

@interface KTDesignFamily : NSObject <IKImageBrowserItem>  {

	NSMutableArray *_designs;
}

- (NSString *) genre;
- (NSString *) color;


- (void) addDesign:(KTDesign *)aDesign;

@property (retain) NSMutableArray *designs;

@end
