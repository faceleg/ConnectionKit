//
//  AmazonListDelegate.h
//  Amazon List
//
//  Created by Mike on 22/12/2006.
//  Copyright 2006-2009 Karelia Software. All rights reserved.
//
//	The central controlling class of the pagelet. Handles HTML layout, product loading &
//	storage, and Inspector accessor methods.


#import <Cocoa/Cocoa.h>
#import "SandvoxPlugin.h"

#import "APAmazonList.h"


typedef enum {
	AmazonPageletPickByHand = 0,
	AmazonPageletLoadFromList = 1,
} AmazonPageletListSource;

extern NSString * const APDisplayTabIdentifier;
extern NSString * const APProductsOrListTabIdentifier;

typedef enum {
	APLayoutLeft = 1,
	APLayoutRight = 2,
	APLayoutAlternating = 3,
	APLayoutCentered = 4,
	APLayoutTwoUp = 5,
	APLayoutBullets = 6,
	APLayoutEnhanced = 7,
	APLayoutRandom = 8,
} APListLayout;

typedef enum {
	APFrameNone = 0,
	APFrameEntirePagelet = 1,
	APFrameThumbnails = 2,
} APFrame;


@class APManualListProduct;
@class AutomaticAmazonListController;


@interface AmazonListDelegate : SVElementPlugIn <KTDataSource>
{
	@private
	
	NSMutableArray	*myProducts;
	
	BOOL	manualListIsBeingArchivedOrUnarchived;
	
	// Automatic list
	APAmazonList	*myAutomaticList;
	NSArray			*myAutomaticListProductsToDisplay;
}

// For both list types
+ (NSString *)CSSClassNameForLayout:(APListLayout)layout;

@end


@interface AmazonListDelegate (ManualList)

- (void)observeValueForKeyPath:(NSString *)keyPath
		   ofManualListProduct:(APManualListProduct *)product
						change:(NSDictionary *)change
					   context:(void *)context;

- (unsigned)thumbnailWidths;
- (NSString *)thumbnailWidthsString;

- (NSArray *)products;
- (void)insertObject:(APManualListProduct *)product inProductsAtIndex:(unsigned)index;
- (void)removeObjectFromProductsAtIndex:(unsigned)index;

- (unsigned)numberOfManualProductsWithAProductCode;
- (NSArray *)productsSuitableForPublishing;

- (void)loadAllManualListProducts;
- (void)archiveManualListProductsAndRegisterUndoOperation:(BOOL)registerUndo;
- (void)unarchiveManualListProductsFromPluginProperties;

@end


@interface AmazonListDelegate (AutomaticList)
// Automatic lists
- (APAmazonList *)automaticList;
- (void)setAutomaticList:(APAmazonList *)list;
- (NSArray *)automaticListProductsToDisplay;
- (void)setAutomaticListProductsToDisplay:(NSArray *)products;
- (void)loadAutomaticList;

@end
