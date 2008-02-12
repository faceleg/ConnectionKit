//
//  NSSortDescriptor+KTExtensions.h
//  Marvel
//
//  Created by Mike on 30/01/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSSortDescriptor (KTExtensions)

// General
+ (NSArray *)orderingSortDescriptors;

// Pages
+ (NSArray *)unsortedPagesSortDescriptors;
+ (NSArray *)alphabeticalTitleTextSortDescriptors;
+ (NSArray *)reverseAlphabeticalTitleTextSortDescriptors;
+ (NSArray *)chronologicalSortDescriptors;	// Eldest first
+ (NSArray *)reverseChronologicalSortDescriptors;	// Newest first


// Pagelets
+ (NSArray *)sidebarPageletsSortDescriptors;

@end
