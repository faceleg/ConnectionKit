//
//  KTDesignManager.h
//  Marvel
//
//  Copyright (c) 2004-2005 Biophony, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class KTDesign;

@interface KTDesignManager : NSObject
{
    NSDictionary					*myDesigns;
	NSArray							*mySortedDesigns;
	IBOutlet NSOutlineView			*oDesignOutlineView;
	IBOutlet NSButton				*oSetButton;
}

- (NSDictionary *)designs;
- (void)setDesigns:(NSDictionary *)aDesigns;

- (NSArray *)sortedDesigns;
- (void)setSortedDesigns:(NSArray *)aSortedDesigns;


- (KTDesign *)designForIdentifier:(NSString *)anIdentifier;

- (NSString *)designReportShowingAll:(BOOL)aShowAll;	// if false, just shows third-party ones

@end

/*
 Unlike KTComponents, KTDesigns are simple covers on NSBundles that provide
 KTDocuments with design information.
 */
