//
//  APAmazonProduct.m
//  Amazon List
//
//  Created by Mike on 02/01/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "AmazonListProduct.h"

#import <AmazonSupport/AmazonSupport.h>

#import "AmazonItem+APExtensions.h"


@interface AmazonListProduct ()
- (void)postProductDidEndLoadingNotifcation;
@end


@implementation AmazonListProduct

# pragma mark *** Init & Dealloc ***

- (id)initWithAmazonItem:(AmazonItem *)item
{
	[self init];
	
	// Store the item
	[self setASIN:[item amazonID]];
	[self setAmazonItem: item];
	
	// Set all product details from the item
	[self setProductDetailsFromAmazonItem];
	
	return self;
}

- (void)dealloc
{
	[myASIN release];
	[myTitle release];
	[myCreator release];
	[myReleaseDate release];
	[myBinding release];
	[myAttributes release];
	[myThumbnail release];
	[myPublishingThumbnailURL release];
	[myComment release];
	
	[myAmazonItem release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Copy

- (id)copyWithZone:(NSZone *)zone
{
	AmazonListProduct *copy = [[[self class] allocWithZone: zone] init];
	
	[copy setASIN: [self ASIN]];
	[copy setTitle: [self title]];
	[copy setCreator: [self creator]];
	[copy setReleaseDate: [self releaseDate]];
	[copy setBinding: [self binding]];
	[copy setThumbnail: [self thumbnail]];
	[copy setComment: [self comment]];
	[copy setLoadingData: [self isLoadingData]];
	
	return copy;
}

#pragma mark -
#pragma mark Accessors

- (AmazonStoreCountry)store { return myStore; }

- (void)setStore:(AmazonStoreCountry)store { myStore = store; }

- (NSString *)ASIN { return myASIN; }

- (void)setASIN:(NSString *)ASIN
{
	ASIN = [ASIN copy];
	[myASIN release];
	myASIN = ASIN;
}

- (NSURL *)URL
{
	NSURL *result = nil;
	
	if ([self ASIN])
	{
		NSURL *storeURL = [AmazonECSOperation URLOfStore:[self store]];
		
		NSString *path = [NSString pathWithComponents:
			[NSArray arrayWithObjects:@"/",
									  @"exec",
									  @"obidos",
									  @"ASIN",
									  [self ASIN],
									  [AmazonECSOperation associateIDForStore:[self store]],
									  nil]];
	
		result = [NSURL URLWithString:path relativeToURL:storeURL];
	}
	
	return result;
}

- (NSString *)title { return myTitle; }

- (void)setTitle:(NSString *)title
{
	title = [title copy];
	[myTitle release];
	myTitle = title;
}

- (NSString *)creator { return myCreator; }

- (void)setCreator:(NSString *)creator
{
	creator = [creator copy];
	[myCreator release];
	myCreator = creator;
}

- (NSString *)releaseDate { return myReleaseDate; }

- (void)setReleaseDate:(NSString *)date
{
	date = [date copy];
	[myReleaseDate release];
	myReleaseDate = date;
}

- (NSString *)binding { return myBinding; }

- (void)setBinding:(NSString *)binding
{
	binding = [binding copy];
	[myBinding release];
	myBinding = binding;
}

- (NSString *)comment { return myComment; }

- (void)setComment:(NSString *)comment
{
	comment = [comment copy];
	[myComment release];
	myComment = comment;
}

- (BOOL)isLoadingData { return myLoadingData; }

- (void)setLoadingData:(BOOL)loadingData
{
	myLoadingData = loadingData;
	
	[self postProductDidEndLoadingNotifcation];
}

# pragma mark -
# pragma mark Thumbnail

- (NSImage *)thumbnail { return myThumbnail; }

- (void)setThumbnail:(NSImage *)thumbnail
{
	[thumbnail retain];
	[myThumbnail release];
	myThumbnail = thumbnail;
}

/*	Find a reasonably large image to use as the product thumbnail on a published page
 */
- (NSURL *)publishingThumbnailURL { return myPublishingThumbnailURL; }

- (void)setPublishingThumbnailURL:(NSURL *)URL
{
	[URL retain];
	[myPublishingThumbnailURL release];
	myPublishingThumbnailURL = URL;
}

- (NSString *)publishingThumbnailURLString
{
	return [[self publishingThumbnailURL] absoluteString];
}

- (void)loadThumbnail
{
	// Download the thumbnail image if it exists
	AmazonImage *thumbnail = [self amazonThumbnailImage];
	
	if (thumbnail) {
		[self setLoadingData: YES];
		[thumbnail loadWithDelegate: self];
	}
}

/*	Figure out which image to use for the Inspector thumbnail
 */
- (AmazonImage *)amazonThumbnailImage
{
	if (!myAmazonThumbnailImage)
	{
		AmazonItem *amazonItem = [self amazonItem];
		myAmazonThumbnailImage = [amazonItem imageToFitSize: NSMakeSize(80.0, 80.0)];
	}
	
	return myAmazonThumbnailImage;
}

- (NSURL *)amazonPublishingSizedImage
{
	AmazonImage *amazonImage = [[self amazonItem] imageToFitWidth: 100.0];
	NSURL *result = [amazonImage requestURL];
	
	return result;
}

- (void)thumbnailDidDownload
{
	// Copy the thumbnail to ourself and the publishing thumbnail URL
	NSImage *thumbnail = [[self amazonThumbnailImage] image];
	[self setThumbnail: thumbnail];
	
	NSURL *publishingThumbnailURL = [self amazonPublishingSizedImage];
	[self setPublishingThumbnailURL: publishingThumbnailURL];
	
	// Tidy up
	[self setLoadingData: NO];
}

#pragma mark -
#pragma mark Help

- (NSString *)description
{
	return [self title];
}

/* A combination of various product attributes */
- (NSString *)toolTipString
{
	NSString *title = [self title];
	if (!title) {
		title = @"";
	}
	
	NSMutableString *result = [NSMutableString stringWithString: title];
	NSString *fragment = nil;
	
	fragment = [self creator];
	if (fragment && ![fragment isEqualToString: @""]) {
		[result appendFormat: @"\n%@", fragment];
	}
	
	fragment = [self releaseDate];
	if (fragment && ![fragment isEqualToString: @""]) {
		[result appendFormat: @"\n%@", fragment];
	}
	
	fragment = [self binding];
	if (fragment && ![fragment isEqualToString: @""]) {
		[result appendFormat: @"\n%@", fragment];
	}
	
	
	return [[result copy] autorelease];
}

#pragma mark -
#pragma mark Amazon Item

- (AmazonItem *)amazonItem { return myAmazonItem; }

- (void)setAmazonItem:(AmazonItem *)item
{
	[item retain];
	[myAmazonItem release];
	myAmazonItem = item;
	
	myAmazonThumbnailImage = nil;	// We also have to reset this variable
}

- (void)setProductDetailsFromAmazonItem
{
	AmazonItem *amazonItem = [self amazonItem];
	NSXMLElement *itemAttributes = [amazonItem attributesXML];
	
	
	[self setASIN: [amazonItem amazonID]];
	//[self setURL: [amazonItem detailsPage]];	/// No longer needed, now generated automatically
	[self setTitle: [itemAttributes stringValueForName: @"Title"]];
	[self setCreator: [amazonItem creator]];
	[self setReleaseDate: [amazonItem releaseDate]];
	[self setBinding: [itemAttributes stringValueForName: @"Binding"]];
}

# pragma mark -
# pragma mark *** Amazon Requests ***

- (void)asyncObject:(id)aRequestedObject didFailWithError:(NSError *)error
{
	// Is the object our thumbnail image?
	if (aRequestedObject == [self amazonThumbnailImage]) {
		[self thumbnailDidDownload];
	}
}

- (void)asyncObjectDidFinishLoading:(id)aRequestedObject
{
	if (aRequestedObject == [self amazonThumbnailImage]) {
		[self thumbnailDidDownload];
	}
}

#pragma mark -
#pragma mark Notifications

- (void)postProductDidEndLoadingNotifcation
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"AmazonProductDidEndLoading"
														object:self];
}

@end
