//
//  RSSBadgePlugin.h
//  RSSBadgeElement
//
//  Created by Dan Wood on 2/24/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SandvoxPlugin.h"

typedef enum {
	RSSBadgeIconStyleNone = 0,
	RSSBadgeIconStyleStandardOrangeSmall = 1,
	RSSBadgeIconStyleStandardOrangeLarge = 2,
	RSSBadgeIconStyleStandardGraySmall = 3,
	RSSBadgeIconStyleStandardGrayLarge = 4,
	RSSBadgeIconStyleAppleRSS = 5,
	RSSBadgeIconStyleFlatXML = 6,
	RSSBadgeIconStyleFlatRSS = 7,
} RSSBadgeIconStyle;

typedef enum {
	RSSBadgeIconPositionLeft = 1,
	RSSBadgeIconPositionRight = 2,
} RSSBadgeIconPosition;


@interface RSSBadgePlugin : SVElementPlugIn {

	RSSBadgeIconStyle _iconStyle;
	NSString *_label;
	KTPage *_collection;
}

// Collection accessors
- (BOOL)useLargeIconLayout;

- (NSString *)feedIconResourcePath;

@property (assign) RSSBadgeIconStyle iconStyle;
@property (copy) NSString *label;
@property (retain) KTPage *collection;


@end
