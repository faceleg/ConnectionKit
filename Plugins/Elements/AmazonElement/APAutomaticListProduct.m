//
//  APAutomaticListProduct.m
//  Amazon List
//
//  Created by Mike on 09/02/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "APAutomaticListProduct.h"

#import <SandvoxPlugin.h>
#import <AmazonSupport/AmazonSupport.h>


@implementation APAutomaticListProduct

#pragma mark Copy

- (id)copyWithZone:(NSZone *)zone
{
	id copy = [super copyWithZone: zone];
	
	[copy setQuantityDesired: [self quantityDesired]];
	[copy setQuantityReceived: [self quantityReceived]];
	
	return copy;
}

#pragma mark Quantities desired and received

- (unsigned)quantityDesired { return myQuantityDesired; }

- (void)setQuantityDesired:(unsigned)quantity { myQuantityDesired = quantity; }

- (unsigned)quantityReceived { return myQuantityReceived; }

- (void)setQuantityReceived:(unsigned)quantity { myQuantityReceived = quantity; }

- (BOOL)desiredQuantityHasBeenReceived
{
	BOOL result = NO;
	
	unsigned desired = [self quantityDesired];
	if (desired > 0 && [self quantityReceived] >= desired) {
		result = YES;
	}
	
	return result;
}

#pragma mark Other

/* For automatic list products, we also set the comment from the XML */
- (void)setProductDetailsFromAmazonItem
{
	[super setProductDetailsFromAmazonItem];
	
	AmazonListItem *amazonItem = (AmazonListItem *)[self amazonItem];
	
	[self setComment: [amazonItem comment]];
	[self setQuantityDesired: [amazonItem quantityDesired]];
	[self setQuantityReceived: [amazonItem quantityReceived]];
}

- (NSString *)toolTipString
{
	NSString *result = [super toolTipString];
	
	NSString *comment = [self comment];
	if (comment) {
		result = [result stringByAppendingFormat: @"\r%@", comment];
	}
	
	// If the product is greyed out explain why
	if ([self desiredQuantityHasBeenReceived]) {
		NSString *explanation = LocalizedStringInThisBundle(@"The desired quantity of this product has been received.", "Tooltip text");
		result = [result stringByAppendingFormat: @"\r%@", explanation];
	}
	
	return result;
}

@end
