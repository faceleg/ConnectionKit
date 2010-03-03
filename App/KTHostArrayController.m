//
//  KTHostArrayController.m
//  Marvel
//
//  Created by Dan Wood on 11/10/04.
//  Copyright 2004-2009 Karelia Software. All rights reserved.
//

/*
PURPOSE OF THIS CLASS/CATEGORY:
	Manage the list of hosts in the host setup setup assistant, to allow us to do search fields.

TAXONOMY AND RELATIONSHIP TO OTHER CLASSES:
	Used in conjunction with KTHostSetupController

IMPLEMENTATION NOTES & CAUTIONS:
	x

TO DO:
	x

 */

#import "KTHostArrayController.h"
#import "NSString+Karelia.h"

@interface NSString ( containsItem )
- (BOOL) containsItem:(NSString *)aSearchString;
@end

@implementation NSString ( containsItem )

- (BOOL) containsItem:(NSString *)aSearchString
{
	BOOL result = NO;
	NSArray *commaSeparatedItems = [self componentsSeparatedByCommas];
	NSEnumerator *theEnum = [commaSeparatedItems objectEnumerator];
	id item;

	while (nil != (item = [theEnum nextObject]) && !result)
	{
		result = ([item rangeOfString:aSearchString options:(NSAnchoredSearch | NSCaseInsensitiveSearch)].location != NSNotFound);
	}
	return result;
}

@end

@implementation KTHostArrayController

/*!	Arrange object according to filter.  We match the filter to the beginning of the ISP name, or to the beginning of any of the words separated by commas in the area.an
*/
- (NSArray *)arrangeObjects:(NSArray *)objects
{

    if (mySearchString == nil || [mySearchString isEqual:@""]) {
        return [super arrangeObjects:objects];
    }

    NSMutableArray *filteredObjects = [NSMutableArray arrayWithCapacity:[objects count]];
    id item;

    for (item in objects)
	{
		NSString *name = [item valueForKeyPath:@"provider"];
		NSString *area = [item valueForKeyPath:@"regions"];
		NSString *domain = [item valueForKeyPath:@"domainName"];

		// First check if domain name matches, anchored at beginning
		BOOL matches = ( nil != domain && [domain rangeOfString:mySearchString options:(NSAnchoredSearch | NSCaseInsensitiveSearch)].location != NSNotFound);

		// If not matching, see if we find it in name list
		// If not matching, see if we find it in area list
		if (!matches && nil != name)
		{
			matches = [name containsItem:mySearchString];
		}

		// If not matching, see if we find it in area list
		if (!matches && nil != area)
		{
			matches = [area containsItem:mySearchString];
		}

		// Now, only add the item if we found a match
		if (matches)
		{
            [filteredObjects addObject:item];
        }
    }
    return [super arrangeObjects:filteredObjects];
}

- (IBAction)search:(id)sender;
{
    // set the search string by getting the stringValue
    // from the sender
    [self setSearchString:[[sender stringValue] stringByTrimmingFirstLine]];
    [self rearrangeObjects];
}

- (void)setSearchString:(NSString *)aString
{
    [aString retain];
    [mySearchString release];
    mySearchString=aString;
}

- (NSString *)searchString
{
    return mySearchString;
}

- (void)dealloc
{
    [self setSearchString: nil];
    [super dealloc];
}

- (IBAction) doHostTableDoubleClick:(id)sender
{
	int row = [sender selectedRow];
	if (row >= 0)
	{

	}

}

@end
