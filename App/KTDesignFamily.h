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
	NSMutableDictionary *_thumbnails;	// keyed by nsnumber for version so it can be arbitrary sized
	NSArray *_colors;
	
	NSUInteger _imageVersion;
}

- (NSString *) genre;
- (NSColor *) color;
- (NSString *) width;

- (void) scrub:(float)howFar;

- (void) addDesign:(KTDesign *)aDesign;

@property (retain) NSMutableArray *designs;
@property (retain) NSMutableDictionary *thumbnails;
@property (retain) NSArray *colors;			// colors of the children design variations, cached
@property (assign) NSUInteger imageVersion;

@end
