//
//  KTPage+Internal.h
//  Marvel
//
//  Created by Mike on 21/10/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//


#import "KTPage.h"
#import "KTAbstractElement+Internal.h"


@class KTAbstractHTMLPlugin;


@interface KTPage (Internal)

// Creation
+ (KTPage *)insertNewPageWithParent:(KTPage *)aParent;

+ (KTPage *)pageWithParent:(KTPage *)aParent
	  dataSourceDictionary:(NSDictionary *)aDictionary insertIntoManagedObjectContext:(NSManagedObjectContext *)aContext;

// Hierarchy
- (BOOL)containsDescendant:(KTPage *)aPotentialDescendant;	// DEPRECATED.  FASTER TO USE isDescendantOfPage:
- (BOOL)isDescendantOfPage:(KTPage *)aPotentialAncestor;

- (int)proposedOrderingForProposedChild:(id)aProposedChild
							   sortType:(KTCollectionSortType)aSortType;
- (int)proposedOrderingForProposedChildWithTitle:(NSString *)aTitle;

@property(nonatomic, retain) KTMaster *master;
@property(nonatomic, retain) KTSite *site;


// Index
- (void)setIndex:(KTAbstractIndex *)anIndex;
- (void)setIndexFromPlugin:(KTAbstractHTMLPlugin *)aBundle;


// New page
- (BOOL)isNewPage;
- (void)setNewPage:(BOOL)flag;

@end


@interface KTPage (Operations)

- (void)setValue:(id)value forKey:(NSString *)key recursive:(BOOL)recursive;

// Perform selector
- (void)makeComponentsPerformSelector:(SEL)selector
						   withObject:(void *)anObject
							 withPage:(KTPage *)page
							recursive:(BOOL)recursive;

- (void)addDesignsToSet:(NSMutableSet *)aSet forPage:(KTPage *)aPage;
- (void)addStaleToSet:(NSMutableSet *)aSet forPage:(KTPage *)aPage;
- (void)addRSSCollectionsToArray:(NSMutableArray *)anArray forPage:(KTPage *)aPage;
- (NSString *)spotlightHTML;


@end


