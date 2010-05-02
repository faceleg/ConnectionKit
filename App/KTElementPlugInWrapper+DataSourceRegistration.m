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

#import "NSString+Karelia.h"

#import "KSWebLocation.h"

#import "Debug.h"


@implementation KTElementPlugInWrapper (DataSourceRegistration)

/*  Returns a set of all the available KTElement classes that conform to the KTDataSource protocol
 */
+ (NSSet *)dataSources
{
    NSDictionary *elements = [KSPlugInWrapper pluginsWithFileExtension:kKTElementExtension];
    NSMutableSet *result = [NSMutableSet setWithCapacity:[elements count]];
	
    
    NSEnumerator *pluginsEnumerator = [elements objectEnumerator];
    KTElementPlugInWrapper *aPlugin;
	while (aPlugin = [pluginsEnumerator nextObject])
    {
		Class anElementClass = [[aPlugin bundle] principalClass];
        if ([anElementClass conformsToProtocol:@protocol(NSPasteboardReading)])
        {
            [result addObject:anElementClass];
        }
    }
	
    return result;
}

+ (NSArray *)insertNewGraphicsWithPasteboard:(NSPasteboard *)pasteboard
                      inManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVGraphic *graphic = [self insertNewGraphicWithPasteboard:pasteboard
                                       inManagedObjectContext:context];
    
    NSArray *result = (graphic) ? [NSArray arrayWithObject:graphic] : nil;
    return result;
}

+ (SVGraphic *)insertNewGraphicWithPasteboard:(NSPasteboard *)pasteboard
                       inManagedObjectContext:(NSManagedObjectContext *)context;
{
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
                NSPasteboardReadingOptions readingOptions = NSPasteboardReadingAsData;
                if ([aSource respondsToSelector:@selector(readingOptionsForType:pasteboard:)])
                {
                    readingOptions = [aSource readingOptionsForType:type pasteboard:pasteboard];
                }
                
                id propertyList;
                if (readingOptions & NSPasteboardReadingAsPropertyList)
                {
                    propertyList = [pasteboard propertyListForType:type];
                }
                else if (readingOptions & NSPasteboardReadingAsString)
                {
                    propertyList = [pasteboard stringForType:type];
                }
                else
                {
                    propertyList = [pasteboard dataForType:type];
                }
                
                
                // Try to create plug-in from property list
                if ( [aSource respondsToSelector:@selector(initWithPasteboardPropertyList:ofType:)] )
                {
                    id <SVPlugIn> plugIn = [[aSource alloc] 
                                            initWithPasteboardPropertyList:propertyList
                                            ofType:type];
                    
                    if (plugIn)
                    {
                        SVGraphic *result = [SVPlugInGraphic insertNewGraphicWithPlugIn:plugIn
                                                                 inManagedObjectContext:context];
                        [plugIn release];
                        
                        return result;
                    }
                }
            }
            @catch (NSException *exception)
            {
                // TODO: Log warning
            }
        }
    }
    
    return nil;
}

#pragma mark -


/*! returns unionSet of acceptedDragTypes from all known KTDataSources */
+ (NSSet *)setOfAllDragSourceAcceptedDragTypesForPagelets:(BOOL)isCreatingPagelet
{
    NSMutableSet *result = [NSMutableSet set];
	
    NSEnumerator *pluginsEnumerator = [[self dataSources] objectEnumerator];
    Class anElementClass;
	while (anElementClass = [pluginsEnumerator nextObject])
    {
		NSArray *acceptedTypes = [anElementClass readableTypesForPasteboard:nil];
        [result addObjectsFromArray:acceptedTypes];
    }
	
    return [NSSet setWithSet:result];
}

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

