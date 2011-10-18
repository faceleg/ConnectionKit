//
//  AmazonMiniItem.m
//  iMediaAmazon
//
//  Created by Dan Wood on 1/19/07.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import "AmazonMiniItem.h"
#import "AmazonImage.h"
#import "NSXMLElement+Amazon.h"

/*
 This is for a mini-item returned from a browse node lookup.  Maybe it makes sense to merge this in with AmazonItem, but we
 don't really have any way to instantiate the rest of it.
 */

@implementation AmazonMiniItem

- (id)initWithXMLElement:(NSXMLElement *)xml
{
	[super init];
	
	myASIN = [[xml stringValueForName: @"ASIN"] copy];
	myTitle = [[xml stringValueForName: @"Title"] copy];
	myThumbnail = nil;
	
	return self;
}

#pragma mark -
#pragma mark Accessors


- (NSString *)ASIN
{
    return myASIN; 
}

- (void)setASIN:(NSString *)anASIN
{
    [anASIN retain];
    [myASIN release];
    myASIN = anASIN;
}

- (NSString *)title
{
    return myTitle; 
}

- (void)setTitle:(NSString *)aTitle
{
    [aTitle retain];
    [myTitle release];
    myTitle = aTitle;
}

- (NSImage *)thumbnail
{
//	NSLog(@"requested thumbnail for %@ %@", [self title], [self ASIN]);
	if (nil == myThumbnail && [NSNull null] != (NSNull *)myThumbnail)
	{
		// kick off a lazy load
		
		AmazonStoreCountry store = [[NSUserDefaults standardUserDefaults] integerForKey:@"AmazonListLastStore"];
		
		AmazonImage *amImage = [[[AmazonImage alloc] initWithSize:AmazonImageSmall ASIN:[self ASIN] country:store] autorelease];
		[amImage loadWithDelegate:self];
		myThumbnail = (NSImage *)[NSNull null];		// put in a placeholder until we're loaded
		
	}
	
	// Return nil, or the thumbnail, but never NSNull.
	return ((NSNull *)myThumbnail == [NSNull null]) ? nil : myThumbnail; 
}

- (void)setThumbnail:(NSImage *)aThumbnail
{
    [aThumbnail retain];
    [myThumbnail release];
    myThumbnail = aThumbnail;
}

- (void)asyncObject:(id)aRequestedObject didFailWithError:(NSError *)error
{
	NSLog(@"amazon item load error %@", error);
}
- (void)asyncObjectDidFinishLoading:(id)aRequestedObject;
{
	[self setThumbnail:[aRequestedObject image]];
//	NSLog(@"received image: %@", [aRequestedObject image]);
}

@end
