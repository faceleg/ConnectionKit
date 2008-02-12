//
//  NSSortDescriptor+KTExtensions.m
//  Marvel
//
//  Created by Mike on 30/01/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "NSSortDescriptor+KTExtensions.h"


@implementation NSSortDescriptor (KTExtensions)

+ (NSArray *)orderingSortDescriptors
{
	static NSArray *result;
	
	if (!result)
	{
		NSSortDescriptor *orderingDescriptor = [[NSSortDescriptor alloc] initWithKey:@"ordering" ascending:YES];
		result = [[NSArray alloc] initWithObjects:orderingDescriptor, nil];
		[orderingDescriptor release];
	}
	
	return result;
}

+ (NSArray *)unsortedPagesSortDescriptors;
{
	static NSArray *result;
	
	if (!result)
	{
		NSSortDescriptor *orderingDescriptor = [[NSSortDescriptor alloc] initWithKey:@"childIndex" ascending:YES];
		result = [[NSArray alloc] initWithObjects:orderingDescriptor, nil];
		[orderingDescriptor release];
	}
	
	return result;
}

+ (NSArray *)alphabeticalTitleTextSortDescriptors
{
	static NSArray *result;
	
	if (!result)
	{
		NSSortDescriptor *orderingDescriptor = [[NSSortDescriptor alloc] initWithKey:@"titleText" ascending:YES selector:@selector(caseInsensitiveCompare:)];
		result = [[NSArray alloc] initWithObject:orderingDescriptor];
		[orderingDescriptor release];
	}
	
	return result;
}

+ (NSArray *)reverseAlphabeticalTitleTextSortDescriptors;
{
	static NSArray *result;
	
	if (!result)
	{
		NSSortDescriptor *orderingDescriptor = [[NSSortDescriptor alloc] initWithKey:@"titleText" ascending:NO selector:@selector(caseInsensitiveCompare:)];
		result = [[NSArray alloc] initWithObject:orderingDescriptor];
		[orderingDescriptor release];
	}
	
	return result;
}

+ (NSArray *)chronologicalSortDescriptors;	// Eldest first
{
	static NSArray *result;
	
	if (!result)
	{
		NSSortDescriptor *orderingDescriptor = [[NSSortDescriptor alloc] initWithKey:@"editableTimestamp" ascending:YES];
		result = [[NSArray alloc] initWithObject:orderingDescriptor];
		[orderingDescriptor release];
	}
	
	return result;
}

+ (NSArray *)reverseChronologicalSortDescriptors;	// Newest first
{
	static NSArray *result;
	
	if (!result)
	{
		NSSortDescriptor *orderingDescriptor = [[NSSortDescriptor alloc] initWithKey:@"editableTimestamp" ascending:NO];
		result = [[NSArray alloc] initWithObject:orderingDescriptor];
		[orderingDescriptor release];
	}
	
	return result;
}

+ (NSArray *)sidebarPageletsSortDescriptors
{
	static NSArray *result;
	
	if (!result)
	{
		NSSortDescriptor *orderingDescriptor = [[NSSortDescriptor alloc] initWithKey:@"ordering" ascending:YES];
		NSSortDescriptor *pageletPrefersBottomDescriptor = [[NSSortDescriptor alloc] initWithKey:@"prefersBottom" ascending:YES];
		result = [[NSArray alloc] initWithObjects:pageletPrefersBottomDescriptor, orderingDescriptor, nil];
		[orderingDescriptor release];
		[pageletPrefersBottomDescriptor release];
	}
	
	return result;
}

@end
