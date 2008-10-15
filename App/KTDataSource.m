//
//  KTDataSource.m
//  KTComponents
//
//  Copyright (c) 2004-2005 Biophony LLC. All rights reserved.
//

#import "KTDataSource.h"

#import "KT.h"
#import "KTImageView.h"

#import "NSString+Karelia.h"

#import "Debug.h"


@implementation KTElementPlugin (DataSourceRegistration)

/*  Returns an set of all the available KTElement classes that conform to the KTDataSource protocol
 */
+ (NSSet *)dataSources
{
    NSDictionary *elements = [KSPlugin pluginsWithFileExtension:kKTElementExtension];
    NSMutableSet *result = [NSMutableSet setWithCapacity:[elements count]];
	
    
    NSEnumerator *pluginsEnumerator = [elements objectEnumerator];
    KTElementPlugin *aPlugin;
	while (aPlugin = [pluginsEnumerator nextObject])
    {
		Class anElementClass = [[aPlugin bundle] principalClass];
        if ([anElementClass conformsToProtocol:@protocol(KTDataSource)])
        {
            [result addObject:anElementClass];
        }
    }
	
    return result;
}

/*! returns unionSet of acceptedDragTypes from all known KTDataSources */
+ (NSSet *)setOfAllDragSourceAcceptedDragTypesForPagelets:(BOOL)isPagelet
{
    NSMutableSet *result = [NSMutableSet set];
	
    NSEnumerator *pluginsEnumerator = [[self dataSources] objectEnumerator];
    Class anElementClass;
	while (anElementClass = [pluginsEnumerator nextObject])
    {
		NSArray *acceptedTypes = [anElementClass supportedDragTypes];
        [result addObjectsFromArray:acceptedTypes];
    }
	
    return [NSSet setWithSet:result];
}

/*!	Ask all the data sources to try to figure out how many items need to be processed in a drag
*/
+ (unsigned)numberOfItemsToProcessDrag:(id <NSDraggingInfo>)draggingInfo;
{
	unsigned result = 1;
    
    NSEnumerator *pluginsEnumerator = [[self dataSources] objectEnumerator];
    Class anElementClass;
	while (anElementClass = [pluginsEnumerator nextObject])
    {
		unsigned multiplicity = [anElementClass numberOfItemsFoundInDrag:draggingInfo];
		if (multiplicity > result) result = multiplicity;
    }
    
    return result;
}

+ (Class <KTDataSource>)highestPriorityDataSourceForDrag:(id <NSDraggingInfo>)draggingInfo
                                                               index:(unsigned)anIndex
                                                   isCreatingPagelet:(BOOL)isCreatingPagelet
{
    NSPasteboard *pboard = [draggingInfo draggingPasteboard];
    NSArray *pboardTypes = [pboard types];
    NSSet *setOfTypes = [NSSet setWithArray:pboardTypes];
	
    Class <KTDataSource> bestDataSource = nil;
    Class <KTDataSource> secondBestDataSource = nil;
	KTSourcePriority bestRating = KTSourcePriorityNone;
    KTSourcePriority secondBestRating = KTSourcePriorityNone;
	
    NSEnumerator *pluginsEnumerator = [[self dataSources] objectEnumerator];
    Class <KTDataSource> anElementClass;
	while (anElementClass = [pluginsEnumerator nextObject])
    {
		// for each dataSource, see if it will handle what's on the pboard
        NSArray *acceptedTypes = [anElementClass supportedDragTypes];
                
        if (acceptedTypes && [setOfTypes intersectsSet:[NSSet setWithArray:acceptedTypes]])
        {
            // yep, so get the rating and see if it's better than our current bestRating
            KTSourcePriority rating = [anElementClass priorityForDrag:draggingInfo atIndex:anIndex];
            if (rating >= bestRating)
            {
                secondBestRating = bestRating;
                secondBestDataSource = bestDataSource;
                
                bestRating = rating;
                bestDataSource = anElementClass;
            }
        }
    }
	
    
    if (bestRating != KTSourcePriorityNone && (bestRating == secondBestRating))
	{
		NSLog(@"Warning: Data sources %@ and %@ both wanted to handle these pasteboard types: %@", 
			  bestDataSource,
              secondBestDataSource,
              [[pboardTypes description] condenseWhiteSpace]);
	}
	
    
    return bestRating ? bestDataSource : nil;
}

/*!	After the drag, clean up.... send message to all data source objects to let them clean up.  Called
 after the last populateDictionary:... invocation.
 */
+ (void)doneProcessingDrag
{
    [KTImageView clearCachedIPhotoInfoDict];
}




@end

