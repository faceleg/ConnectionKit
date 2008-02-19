//
//  RSSBadgeDelegate.h
//  RSS Badge
//
//  Created by Mike on 20/11/2006.
//  Copyright 2006 Karelia. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Sandvox.h>


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


@class MAImagePopUpButton;


@interface RSSBadgeDelegate : KTAbstractPluginDelegate
{
	IBOutlet KTLinkSourceView	*collectionLinkSourceView;
	IBOutlet MAImagePopUpButton	*iconTypePopupButton;
}

// IB Actions
- (IBAction)clearCollectionLink:(id)sender;

// Collection accessors
- (BOOL)useLargeIconLayout;

- (NSString *)feedIconResourcePath;

@end
