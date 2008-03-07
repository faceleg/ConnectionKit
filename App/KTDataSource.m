//
//  KTDataSource.m
//  KTComponents
//
//  Copyright (c) 2004-2005 Biophony LLC. All rights reserved.
//

#import "KTDataSource.h"

#import "Debug.h"
#import "KT.h"
#import "KTAppDelegate.h"
#import "NSObject+Karelia.h"
#import "NSObject+KTExtensions.h"
#import "NSString+Karelia.h"

#ifdef APP_RELEASE
#import "Registration.h"
#endif


@implementation KTDataSource

+ (void)load
{
	[self registerPluginClass:[KTDataSource class] forFileExtension:kKTDataSourceExtension];
}

/*!	After the drag, clean up.... send message to all data source objects to let them clean up.  Called
	after the last populateDictionary:... invocation.
*/
+ (void) doneProcessingDrag
{
    NSDictionary *dataSources = [KTDataSource pluginDict];
    NSEnumerator  *e = [dataSources objectEnumerator];
    KTDataSource *dataSource;
	
    while ( dataSource = [e nextObject] )
    {
		[dataSource doneProcessingDrag];
    }
}

/*!	For each subclass to have the opportunity to clean up any cache it may have built
*/
- (void) doneProcessingDrag
{
	;
}


/*!	Ask all the data sources to try to figure out how many items need to be processed in a drag
*/
+ (int) numberOfItemsToProcessDrag:(id <NSDraggingInfo>)draggingInfo;
{
	int result = 1;
    NSDictionary *dataSources = [KTDataSource pluginDict];
    NSEnumerator  *e = [dataSources objectEnumerator];
    KTDataSource *dataSource;
		
    while ( dataSource = [e nextObject] )
    {
		int multiplicity = [dataSource numberOfItemsFoundInDrag:draggingInfo];
		if (multiplicity > result)
		{
			result = multiplicity;
		}
    }
    return result;
}

+ (KTDataSource *)highestPriorityDataSourceForDrag:(id <NSDraggingInfo>)draggingInfo index:(unsigned int)anIndex isCreatingPagelet:(BOOL)isCreatingPagelet;
{
    NSPasteboard *pboard = [draggingInfo draggingPasteboard];
    NSArray *pboardTypes = [pboard types];
    NSSet *setOfTypes = [NSSet setWithArray:pboardTypes];
	
    NSDictionary *dataSources = [KTDataSource pluginDict];
    NSEnumerator  *e = [dataSources objectEnumerator];
    KTDataSource *dataSource;
	
    KTDataSource *bestDataSource = nil;
    KTDataSource *secondBestDataSource = nil;
	int bestRating = 0;
   int secondBestRating = 0;
	
    while ( dataSource = [e nextObject] )
    {
		// If non-pro and HTMLSource, don't allow.  So if Pro or NOT data source, allow.
		if ([[NSApp delegate] isPro]
			|| ! [NSStringFromClass([dataSource class]) isEqualToString:@"HTMLSource"])
		{
			// for each dataSource, see if it will handle what's on the pboard
			NSArray *acceptedTypes = [dataSource acceptedDragTypesCreatingPagelet:isCreatingPagelet];
			if ( nil != acceptedTypes && [setOfTypes intersectsSet:[NSSet setWithArray:acceptedTypes]] )
			{
				// yep, so get the rating and see if it's better than our current bestRating
				int rating = [dataSource priorityForDrag:draggingInfo index:anIndex];
				if ( rating >= bestRating )
				{
					secondBestRating = bestRating;
					secondBestDataSource = bestDataSource;
					
					bestRating = rating;
					bestDataSource = dataSource;
				}
			}
		}
    }
	if (bestRating != 0 && (bestRating == secondBestRating))
	{
		NSLog(@"Warning: Data sources %@ and %@ both wanted to handle these pasteboard types: %@", 
			  [bestDataSource class], [secondBestDataSource class], [[pboardTypes description] condenseWhiteSpace]);
	}
	
    return bestRating ? bestDataSource : nil;
}

/*!	Return an array of accepted drag types, with best/richest types first
*/
- (NSArray *)acceptedDragTypesCreatingPagelet:(BOOL)isPagelet;
{
	//[self subclassResponsibility:_cmd];
	//return nil;
	LOG((@"%@ should be implementing acceptedDragTypes", [self class]));
	return nil;
}

/*! returns KTSourcePriorty for draggingPasteboard */
- (int)priorityForDrag:(id <NSDraggingInfo>)draggingInfo index:(unsigned int)anIndex;
{
	LOG((@"%@ should be implementing draggingInfo index:(unsigned int)anIndex", [self class]));
    return KTSourcePriorityNone;
}

/*!	Optional: examine pasteboard and return a number > 1 if it looks like there are multiple items to process
*/
- (unsigned int)numberOfItemsFoundInDrag:(id <NSDraggingInfo>)sender
{
	return 1;
}

/*! asks datasource to accept drop of draggingPasteboard, utilizing/supplying values via aDictionary */
- (BOOL)populateDictionary:(NSMutableDictionary *)aDictionary
				forPagelet:(BOOL)isAPagelet
		  fromDraggingInfo:(id <NSDraggingInfo>)draggingInfo
					 index:(unsigned int)anIndex;
{
	[self subclassResponsibility:_cmd];
	return false;
}

- (NSString *)pageBundleIdentifier
{
	return nil;	// not defined unless overridden
}
- (NSString *)pageletBundleIdentifier
{
	return nil;	// not defined unless overridden
}


/*! returns unionSet of acceptedDragTypes from all known KTDataSources */
+ (NSSet *)setOfAllDragSourceAcceptedDragTypesForPagelets:(BOOL)isPagelet
{
    NSMutableSet *typesSet = [NSMutableSet setWithCapacity:10];
	
    NSEnumerator *e = [[self pluginDict] objectEnumerator];
    id dataSource;
	
    while (dataSource = [e nextObject] )
    {
		NSArray *acceptedTypes = [dataSource acceptedDragTypesCreatingPagelet:isPagelet];
		if (nil != acceptedTypes)
		{
			[typesSet addObjectsFromArray:acceptedTypes];
		}
    }
	
    return [NSSet setWithSet:typesSet];
}

/*! returns array of setOfAllDragSourceAcceptedDragTypesForPagelets:(BOOL)isPagelet */
+ (NSArray *)allDragSourceAcceptedDragTypesForPagelets:(BOOL)isPagelet
{
    return [NSArray arrayWithArray:[[self setOfAllDragSourceAcceptedDragTypesForPagelets:isPagelet] allObjects]];
}


@end
