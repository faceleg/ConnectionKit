//
//  APAmazonProduct.h
//  Amazon List
//
//  Created by Mike on 02/01/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//
//	Represents a general Amazon product as the user will see it in the Inspector.
//	When using -setProductDetailsFromAmazonItem: calling -loadThumbnail will download
//	the smallest available product image to fit 80x80 pixels
//	(this is for resolution independence later).


#import <Cocoa/Cocoa.h>
#import <AmazonSupport/AmazonSupport.h>


@class AmazonListPlugIn;

@class AmazonItem;
@class AmazonImage;


@interface AmazonListProduct : NSObject <NSCopying>
{
	AmazonStoreCountry	myStore;
	NSString			*myASIN;
	NSString			*myTitle;
	NSString			*myCreator;
	NSString			*myReleaseDate;
	NSString			*myBinding;
	NSDictionary		*myAttributes;
	NSImage				*myThumbnail;
	NSURL				*myPublishingThumbnailURL;
	NSString			*myComment;
	BOOL				myLoadingData;
	
	AmazonItem	*myAmazonItem;
	AmazonImage	*myAmazonThumbnailImage;
}

// Init
- (id)initWithAmazonItem:(AmazonItem *)item;

// Accessors
- (AmazonStoreCountry)store;
- (void)setStore:(AmazonStoreCountry)store;

- (NSString *)ASIN;
- (void)setASIN:(NSString *)ASIN;

- (NSURL *)URL;

- (NSString *)title;
- (void)setTitle:(NSString *)title;

- (NSString *)creator;
- (void)setCreator:(NSString *)creator;

- (NSString *)releaseDate;
- (void)setReleaseDate:(NSString *)date;

- (NSString *)binding;
- (void)setBinding:(NSString *)binding;

- (NSString *)comment;
- (void)setComment:(NSString *)comment;

- (BOOL)isLoadingData;
- (void)setLoadingData:(BOOL)loadingData;

// Thumbnail
- (NSImage *)thumbnail;
- (void)setThumbnail:(NSImage *)thumbnail;

- (NSURL *)publishingThumbnailURL;
- (void)setPublishingThumbnailURL:(NSURL *)URL;
- (NSString *)publishingThumbnailURLString;

- (AmazonImage *)amazonThumbnailImage;
- (NSURL *)amazonPublishingSizedImage;
- (void)loadThumbnail;	// Loads just the thumbnail if one has been found
- (void)thumbnailDidDownload;	// Called after the AmazonImage has loaded

// Tooltip
- (NSString *)toolTipString;

// Amazon Item
- (AmazonItem *)amazonItem;
- (void)setAmazonItem:(AmazonItem *)item;
- (void)setProductDetailsFromAmazonItem;

@end
