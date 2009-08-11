//
//  APManualListProduct.m
//  Amazon List
//
//  Created by Mike on 02/01/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "APManualListProduct.h"

#import <AmazonSupport/AmazonSupport.h>
#import "SandvoxPlugin.h"

#import "NSURL+AmazonPagelet.h"


@interface APManualListProduct ()

// Item Lookup
- (void)setLastLoadError:(NSError *)error;
- (AmazonItemLookup *)itemLookupOperation;
- (void)setItemLookupOperation:(AmazonItemLookup *)lookup;
- (void)itemLookupDidFailWithError:(NSError *)error;
- (void)itemLookupDidFinish;
@end


# pragma mark -


@implementation APManualListProduct

#pragma mark -
#pragma mark Init & Dealloc

- (void)dealloc
{
	// If the request is still running, cancel it
	AmazonItemLookup *lookupOp = [self itemLookupOperation];
	if ([lookupOp dataIsLoading])
		[lookupOp cancel];
	
    [myItemLookupOp setDelegate:nil];
	[myItemLookupOp release];
	
    [myProductCode release];
	[myLastLoadError release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Copy

- (id)copyWithZone:(NSZone *)zone
{
	id copy = [super copyWithZone:zone];
	[copy setLastLoadError:[self lastLoadError]];
	return copy;
}

#pragma mark -
#pragma mark Archiving

- (id)initWithCoder:(NSCoder *)coder
{
	[self init];
	
	[self setASIN:[coder decodeObjectForKey:@"ASIN"]];
	[self setProductCode: [coder decodeObjectForKey:@"code"]];
	[self setTitle: [coder decodeObjectForKey: @"title"]];
	//[self setURL: [coder decodeObjectForKey: @"URL"]];	/// No longer needed, now generated automatically
	[self setCreator: [coder decodeObjectForKey: @"creator"]];
	[self setReleaseDate: [coder decodeObjectForKey: @"releaseDate"]];
	[self setBinding: [coder decodeObjectForKey: @"binding"]];
	[self setThumbnail: [coder decodeObjectForKey: @"thumbnail"]];
	[self setPublishingThumbnailURL: [coder decodeObjectForKey: @"publishingThumbnailURL"]];
	[self setComment: [coder decodeObjectForKey: @"comment"]];
	[self setStore: [coder decodeIntForKey: @"store"]];
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	if (![coder allowsKeyedCoding])
		return;
	
	[coder encodeObject:[self ASIN] forKey:@"ASIN"];
	[coder encodeObject: [self productCode] forKey: @"code"];
	//[coder encodeObject: [self URL] forKey: @"URL"];	/// No longer needed, now generated automatically
	[coder encodeObject: [self title] forKey: @"title"];
	[coder encodeObject: [self creator] forKey: @"creator"];
	[coder encodeObject: [self releaseDate] forKey: @"releaseDate"];
	[coder encodeObject: [self binding] forKey: @"binding"];
	[coder encodeObject: [self thumbnail] forKey: @"thumbnail"];
	[coder encodeObject: [self publishingThumbnailURL] forKey: @"publishingThumbnailURL"];
	[coder encodeObject: [self comment] forKey: @"comment"];
	[coder encodeInt: [self store] forKey: @"store"];
}

#pragma mark -
#pragma mark Product Loading

- (void)load
{
	[self clearProductData];
	
	// Don't bother if no ID has been entered
	NSString *productCode = [self productCode];
	if (!productCode || [productCode isEqualToString: @""]) {
		[self setLoadingData:NO];
		return;
	}
	
	[self setLoadingData: YES];
	
	// Create an Amazon Lookup Request to load the details
	AmazonItemLookup *request = [[AmazonItemLookup alloc] initWithStore: [self store]
																 itemID: productCode
																 IDType: [self productCodeIDType]];
	
	[self setItemLookupOperation: request];
	[request loadWithDelegate: self];
	[request release];
}

- (NSError *)lastLoadError { return myLastLoadError; }

- (void)setLastLoadError:(NSError *)error
{
	[error retain];
	[myLastLoadError release];
	myLastLoadError = error;
}

#pragma mark -
#pragma mark Product Code

- (NSString *)productCode { return myProductCode; }

- (void)setProductCode:(NSString *)code
{
	code = [code copy];
	[myProductCode release];
	myProductCode = code;
}

- (BOOL)validateProductCode:(NSString **)code error:(NSError **)error
{
	if (*code != nil)
	{
		// Is the code a URL? 
		NSURL *URL = [NSURL URLWithString:*code];
		if (URL && [URL hasNetworkLocation])
		{
			// Set our store from the product code if possible
			AmazonStoreCountry store = [URL amazonStore];
			if (store != AmazonStoreUnknown) {
				[self setStore:store];
			}
			
			// Convert the URL to an ASIN if possible
			NSString *ASIN = [URL amazonProductASIN];
			if (ASIN) {
				*code = ASIN;
			}
		}
	}
	
	return YES;
}

- (AmazonIDType)productCodeIDType;
{
	// ISBNs are 13 characters. Everythin else is an ASIN
	AmazonIDType result = AmazonIDTypeASIN;
	
	if ([[self productCode] length] == 13) {
		result = AmazonIDTypeISBN;
	}
	
	return result;
}

#pragma mark -
#pragma mark Other Accessors

- (void)clearProductData
{
	[self setTitle: nil];
	[self setCreator: nil];
	[self setReleaseDate: nil];
	[self setBinding: nil];
	[self setThumbnail: nil];
}

#pragma mark -
#pragma mark Enhanced Display

- (NSURL *)enhancedDisplayIFrameURL
{
	return [AmazonECSOperation enhancedProductLinkForASINs:[NSArray arrayWithObject:[self ASIN]]
													 store:[self store]];
}

# pragma mark -
# pragma mark Item Lookup

- (AmazonItemLookup *)itemLookupOperation { return myItemLookupOp; }

- (void)setItemLookupOperation:(AmazonItemLookup *)lookup
{
	// Cancel the old Amazon operations
	[[self amazonThumbnailImage] cancel];
	[myItemLookupOp cancel];
	
	[lookup retain];
	[myItemLookupOp release];
	myItemLookupOp = lookup;
}

- (void)itemLookupDidFailWithError:(NSError *)error
{
	// Tidy up
	[self clearProductData];
	[self setLastLoadError:error];
	
	[self setLoadingData: NO];
	[self setItemLookupOperation: nil];
}

- (void)itemLookupDidFinish
{
	AmazonItemLookup *lookupOp = [self itemLookupOperation];
	
		
	// Store the resultant Amazon item
	[self setAmazonItem: [[lookupOp returnedItems] firstObjectKS]];
	[self setProductDetailsFromAmazonItem];
	
	// Download the product thumbnail
	[self setLastLoadError:nil];
	[self setLoadingData: NO];
	[self loadThumbnail];
}

# pragma mark *** Amazon Requests ***

- (void)asyncObject:(id)aRequestedObject didFailWithError:(NSError *)error
{
	// Pass the message onto the appropriate method
	if (aRequestedObject == [self itemLookupOperation]) {
		[self itemLookupDidFailWithError: error];
	}
	else if (aRequestedObject == [self amazonThumbnailImage]) {
		[self thumbnailDidDownload];
	}
}

- (void)asyncObjectDidFinishLoading:(id)aRequestedObject
{
	if (aRequestedObject == [self itemLookupOperation]) {
		[self itemLookupDidFinish];
	}
	else if (aRequestedObject == [self amazonThumbnailImage]) {
		[self thumbnailDidDownload];
	}
}

@end
