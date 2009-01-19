//
//  NSURL+AmazonPagelet.h
//  Amazon List
//
//  Created by Mike on 10/01/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//
//	Category on NSURL for retrieving Amazon information from a URL.


#import <Cocoa/Cocoa.h>
#import <AmazonSupport/AmazonSupport.h>


@interface NSURL (AmazonPagelet)

// Amazon URLs
- (AmazonStoreCountry)amazonStore;
- (NSString *)amazonProductASIN;
- (void)getAmazonListType:(AmazonListType *)listType andID:(NSString **)listId;

@end


@interface NSString (NSURLAmazonPagelet)
- (BOOL)isLikelyToBeAmazonListID;
@end
