//
//  AmazonMiniItem.h
//  iMediaAmazon
//
//  Created by Dan Wood on 1/19/07.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class AmazonImage;

@interface AmazonMiniItem : NSObject {

	NSString *myASIN;
	NSString *myTitle;
	NSImage *myThumbnail;
}

- (NSString *)ASIN;
- (void)setASIN:(NSString *)anASIN;

- (NSString *)title;
- (void)setTitle:(NSString *)aTitle;

- (NSImage *)thumbnail;
- (void)setThumbnail:(NSImage *)aThumbnail;







@end
