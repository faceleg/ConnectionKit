//
//  KTPage+Internal.h
//  Marvel
//
//  Created by Mike on 21/10/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//


#import "KTPage.h"


@class KTHTMLPlugInWrapper;


@interface KTPage (Internal)

// Creation
+ (KTPage *)insertNewPageWithParent:(KTPage *)aParent;

+ (KTPage *)pageWithParent:(KTPage *)aParent
	  dataSourceDictionary:(NSDictionary *)aDictionary insertIntoManagedObjectContext:(NSManagedObjectContext *)aContext;


// Hierarchy
- (int)proposedOrderingForProposedChild:(id)aProposedChild
							   sortType:(SVCollectionSortOrder)aSortType
                              ascending:(BOOL)ascending;

- (int)proposedOrderingForProposedChildWithTitle:(NSString *)aTitle;


// Index
- (void)setIndex:(KTAbstractIndex *)anIndex;
- (void)setIndexFromPlugin:(KTHTMLPlugInWrapper *)aBundle;


@end


@interface KTPage (Operations)

- (void)setValue:(id)value forKey:(NSString *)key recursive:(BOOL)recursive;

- (void)addDesignsToSet:(NSMutableSet *)aSet forPage:(KTPage *)aPage;
- (void)addStaleToSet:(NSMutableSet *)aSet forPage:(KTPage *)aPage;
- (void)addRSSCollectionsToArray:(NSMutableArray *)anArray forPage:(KTPage *)aPage;


@end


