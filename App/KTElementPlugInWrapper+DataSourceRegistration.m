//
//  KTElementPlugInWrapper+DataSourceRegistration.m
//  Marvel
//
//  Created by Mike on 16/10/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTElementPlugInWrapper+DataSourceRegistration.h"

#import "KT.h"
#import "KTImageView.h"
#import "SVPlugInGraphic.h"

#import "NSArray+Karelia.h"
#import "NSString+Karelia.h"

#import "KSWebLocation.h"

#import "Debug.h"


@implementation KTElementPlugInWrapper (DataSourceRegistration)

+ (NSArray *)graphicsFomPasteboard:(NSPasteboard *)pasteboard
    insertIntoManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVGraphic *graphic = [self graphicFromPasteboard:pasteboard
                                       insertIntoManagedObjectContext:context];
    
    NSArray *result = (graphic) ? [NSArray arrayWithObject:graphic] : nil;
    return result;
}

+ (SVGraphic *)graphicFromPasteboard:(NSPasteboard *)pasteboard
      insertIntoManagedObjectContext:(NSManagedObjectContext *)context;
{
    Class plugInClass = nil;
    id pasteboardContents;
    NSString *pasteboardType;
    NSUInteger readingPriority = 0;
    
    
    NSArray *datasources = [[self dataSources] allObjects];
    for (Class aSource in datasources)
    {
        NSArray *types = [aSource readableTypesForPasteboard:pasteboard];
        NSString *type = [pasteboard availableTypeFromArray:types];
        if (type)
        {
            @try    // talking to a plug-in so might fail
            {
                // What should I read off the pasteboard?
                id propertyList;
                SVPlugInPasteboardReadingOptions readingOptions = SVPlugInPasteboardReadingAsData;
                if ([aSource respondsToSelector:@selector(readingOptionsForType:pasteboard:)])
                {
                    readingOptions = [aSource readingOptionsForType:type pasteboard:pasteboard];
                }
                
                if (readingOptions & SVPlugInPasteboardReadingAsPropertyList)
                {
                    propertyList = [pasteboard propertyListForType:type];
                }
                else if (readingOptions & SVPlugInPasteboardReadingAsString)
                {
                    propertyList = [pasteboard stringForType:type];
                }
                else if (readingOptions & SVPlugInPasteboardReadingAsWebLocation)
                {
                    propertyList = [[KSWebLocation webLocationsFromPasteboard:pasteboard] firstObjectKS];
                }
                else
                {
                    propertyList = [pasteboard dataForType:type];
                }
                
                
                if (propertyList)
                {
                    NSUInteger priority = [aSource readingPriorityForPasteboardContents:propertyList
                                                                                 ofType:type];
                    if (priority > readingPriority)
                    {
                        plugInClass = aSource;
                        pasteboardContents = propertyList;
                        pasteboardType = type;
                        readingPriority = priority;
                    }
                }
            }
            @catch (NSException *exception)
            {
                // TODO: Log warning
            }
        }
    }
    
    
    
    
    
    // Try to create plug-in from pasteboard contents
    if (plugInClass)
    {
        NSString *identifier = [plugInClass plugInIdentifier];
        
        SVPlugInGraphic *result = [SVPlugInGraphic insertNewGraphicWithPlugInIdentifier:identifier
                                                                 inManagedObjectContext:context];
        id plugIn = [result plugIn];
        [plugIn awakeFromPasteboardContents:pasteboardContents ofType:pasteboardType];
        
        return result;
    }
    
    
    
    return nil;
}

#pragma mark -

/*!	Ask all the data sources to try to figure out how many items need to be processed in a drag
 */
+ (NSUInteger)numberOfItemsInPasteboard:(NSPasteboard *)pasteboard;
{
	unsigned result = 1;
    
    NSEnumerator *pluginsEnumerator = [[self dataSources] objectEnumerator];
    Class anElementClass;
	while (anElementClass = [pluginsEnumerator nextObject])
    {
		unsigned multiplicity = [anElementClass numberOfItemsFoundOnPasteboard:pasteboard];
		if (multiplicity > result) result = multiplicity;
    }
    
    return result;
}

+ (Class <KTDataSource>)highestPriorityDataSourceForPasteboard:(NSPasteboard *)pboard
                                                   index:(unsigned)anIndex
                                       isCreatingPagelet:(BOOL)isCreatingPagelet
{
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
        NSArray *acceptedTypes = [anElementClass readableTypesForPasteboard:pboard];
        
        if (acceptedTypes && [setOfTypes intersectsSet:[NSSet setWithArray:acceptedTypes]])
        {
            // yep, so get the rating and see if it's better than our current bestRating
            KTSourcePriority rating = (KTSourcePriority)[anElementClass priorityForItemOnPasteboard:pboard atIndex:anIndex creatingPagelet:isCreatingPagelet];
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
    [NSImage clearCachedIPhotoInfoDict];
}




@end

