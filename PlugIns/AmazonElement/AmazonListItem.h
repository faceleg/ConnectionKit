//
//  AmazonListItem.h
//  Amazon List
//
//  Created by Mike on 16/01/2007.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//
//	Extends the AmazonItem class by also loading data specific to a list.
//	i.e. comments, and product quantities.
//	AmazonListLookup operations return AmazonListItems.


#import <Cocoa/Cocoa.h>
#import "AmazonItem.h"


@interface AmazonListItem : AmazonItem
{
	@private
	
	NSString	*myComment;
	NSUInteger	myQuantityReceived;
	NSUInteger	myQuantityDesired;
}

- (NSString *)comment;
- (NSUInteger)quantityDesired;
- (NSUInteger)quantityReceived;

@end
