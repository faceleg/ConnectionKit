//
//  NSURL+AmazonPagelet.h
//  Amazon List
//
//  Created by Mike on 10/01/2007.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//
//	Category on NSURL for retrieving Amazon information from a URL.


#import <Cocoa/Cocoa.h>
#import "AmazonSupport.h"


@interface NSURL (AmazonPagelet)

// Amazon URLs
- (AmazonStoreCountry)amazonStore;
- (NSString *)amazonProductASIN;

@end


@interface NSString (NSURLAmazonPagelet)
- (BOOL)isLikelyToBeAmazonListID;
- (NSString *)amazonList_stringByRemovingCharactersNotInSet:(NSCharacterSet *)validCharacters;
@end
