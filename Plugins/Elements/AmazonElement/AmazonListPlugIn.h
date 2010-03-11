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


@interface AmazonListPlugIn : SVPageletPlugIn <KTDataSource>
{
  @private
    AmazonStoreCountry      _store;
    AmazonPageletListSource _listSource;
    APListLayout            _layout;
    BOOL                    _showProductPreviews;
    NSInteger               _frame;
    NSInteger               _centeredThumbnailWidths;
    
    NSString                *_automaticListCode;
    AmazonListType          _automaticListType;
    AmazonWishListSorting   _automaticListSorting;
    BOOL                    _showPrices;
	BOOL                    _showThumbnails;
    BOOL                    _showNewPricesOnly;
    BOOL                    _showTitles;
    NSInteger               _maxNumberProducts;
    BOOL                    _showComments;
    BOOL                    _showCreators;
    BOOL                    _showLinkToList;
    
    
	NSMutableArray	*_products;
	
	BOOL	manualListIsBeingArchivedOrUnarchived;
	
	// Automatic list
	APAmazonList	*myAutomaticList;
	NSArray			*myAutomaticListProductsToDisplay;
}

@property(nonatomic) AmazonStoreCountry store;
@property(nonatomic) AmazonPageletListSource listSource;
@property(nonatomic) APListLayout layout;
@property(nonatomic) BOOL showProductPreviews;
@property(nonatomic) NSInteger frame;
@property(nonatomic) NSInteger centeredThumbnailWidths;

@property(nonatomic, copy) NSString *automaticListCode;
@property(nonatomic) AmazonListType automaticListType;
@property(nonatomic) AmazonWishListSorting automaticListSorting;
@property(nonatomic) BOOL showPrices;
@property(nonatomic) BOOL showThumbnails;
@property(nonatomic) BOOL showNewPricesOnly;
@property(nonatomic) BOOL showTitles;
@property(nonatomic) NSInteger maxNumberProducts;
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


@interface AmazonListPlugIn (AutomaticList)
// Automatic lists
- (APAmazonList *)automaticList;
- (void)setAutomaticList:(APAmazonList *)list;
- (NSArray *)automaticListProductsToDisplay;
- (void)setAutomaticListProductsToDisplay:(NSArray *)products;
- (void)loadAutomaticList;

@end
