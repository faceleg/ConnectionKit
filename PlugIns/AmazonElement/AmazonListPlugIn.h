//
//  AmazonListDelegate.h
//  Amazon List
//
//  Created by Mike on 22/12/2006.
//  Copyright 2006-2011 Karelia Software. All rights reserved.
//
//	The central controlling class of the pagelet. Handles HTML layout, product loading &
//	storage, and Inspector accessor methods.


#import "Sandvox.h"

#import "AmazonSupport.h"


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


@interface AmazonListPlugIn : SVPlugIn
{
  @private
    AmazonStoreCountry      _store;
    APListLayout            _layout;
    BOOL                    _showProductPreviews;
    NSInteger               _frame;
    NSInteger               _centeredThumbnailWidths;
    
    BOOL                    _showPrices;
	BOOL                    _showThumbnails;
    BOOL                    _showNewPricesOnly;
    BOOL                    _showTitles;
    BOOL                    _showComments;
    BOOL                    _showCreators;
    BOOL                    _showLinkToList;
    
    
	NSMutableArray	*_products;
	
	BOOL	manualListIsBeingArchivedOrUnarchived;
}

@property(nonatomic) AmazonStoreCountry store;
@property(nonatomic) APListLayout layout;
@property(nonatomic) BOOL showProductPreviews;
@property(nonatomic) NSInteger frame;
@property(nonatomic) NSInteger centeredThumbnailWidths;

@property(nonatomic) BOOL showPrices;
@property(nonatomic) BOOL showThumbnails;
@property(nonatomic) BOOL showNewPricesOnly;
@property(nonatomic) BOOL showTitles;
@property(nonatomic) BOOL showComments;
@property(nonatomic) BOOL showCreators;
@property(nonatomic) BOOL showLinkToList;


#pragma mark Markup
// For both list types
- (NSString *)layoutCSSClassName;
+ (NSString *)CSSClassNameForLayout:(APListLayout)layout;


@end


@interface AmazonListPlugIn (ManualList)

- (void)observeValueForKeyPath:(NSString *)keyPath
		   ofManualListProduct:(APManualListProduct *)product
						change:(NSDictionary *)change
					   context:(void *)context;
- (NSSet *)productChangeKeyPaths;

- (unsigned)thumbnailWidths;
- (NSString *)thumbnailWidthsString;

- (NSArray *)products;
- (void)insertObject:(APManualListProduct *)product inProductsAtIndex:(unsigned)index;
- (void)removeObjectFromProductsAtIndex:(unsigned)index;

- (unsigned)numberOfManualProductsWithAProductCode;
- (NSArray *)productsSuitableForPublishing;

- (void)loadAllManualListProducts;
- (void)archiveManualListProductsAndRegisterUndoOperation:(BOOL)registerUndo;

@end
