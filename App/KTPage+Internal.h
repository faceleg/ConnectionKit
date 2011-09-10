//
//  KTPage+Internal.h
//  Marvel
//
//  Created by Mike on 21/10/2008.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//


#import "KTPage.h"


@class KTElementPlugInWrapper;


@interface KTPage (Internal)

// Hierarchy
- (int)proposedOrderingForProposedChildWithTitle:(NSString *)aTitle;


@end


@interface KTPage (Operations)

- (void)setValue:(id)value forKey:(NSString *)key recursive:(BOOL)recursive;

- (void)addDesignsToSet:(NSMutableSet *)aSet forPage:(KTPage *)aPage;
- (void)addStaleToSet:(NSMutableSet *)aSet forPage:(KTPage *)aPage;
- (void)addRSSCollectionsToArray:(NSMutableArray *)anArray forPage:(KTPage *)aPage;


@end


