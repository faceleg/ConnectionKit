//
//  AmazonItem+APExtensions.h
//  Amazon List
//
//  Created by Mike on 29/01/2007.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//
//	Simple extension to the AmazonItem class to provide convenience
//	methods for retrieving a product's creator and release date.


#import <Cocoa/Cocoa.h>
#import "AmazonSupport.h"


@interface AmazonItem (APExtensions)

- (NSString *)creator;
- (NSString *)releaseDate;

@end
