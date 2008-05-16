//
//  KTDocumentInfo.m
//  KTComponents
//
//  Created by Terrence Talbot on 5/21/05.
//  Copyright 2005 Karelia Software. All rights reserved.
//

#import "KTDocumentInfo.h"

#import "KT.h"
#import "KTAppDelegate.h"
#import "KTDocument.h"
#import "KTManagedObjectContext.h"
#import "KTPersistentStoreCoordinator.h"

#import "NSApplication+Karelia.h"
#import "NSArray+Karelia.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSString+Karelia.h"


@interface KTDocumentInfo (Private)
- (NSArray *)_pagesInSiteMenu;
+ (NSArray *)_siteMenuSortDescriptors;
@end


@implementation KTDocumentInfo

#pragma mark -
#pragma mark Init

- (void)awakeFromInsert
{
	[super awakeFromInsert];
	
	
	// Give ourself a unique ID
	NSString *siteID = [NSString shortGUIDString];
    [self setValue:siteID forKey:@"siteID"];
	
	
	// Create Host Properties object as well.
	NSManagedObject *hostProperties = [NSEntityDescription insertNewObjectForEntityForName:@"HostProperties"
																	inManagedObjectContext:[self managedObjectContext]];
	[self setValue:hostProperties forKey:@"hostProperties"];
	
	
	// Copy media originals setting
	[self setCopyMediaOriginals:[[NSUserDefaults standardUserDefaults] integerForKey:@"copyMediaOriginals"]];
}

#pragma mark -
#pragma mark Accessors

- (KTPage *)root { return [self wrappedValueForKey:@"root"]; }

- (KTHostProperties *)hostProperties { return [self wrappedValueForKey:@"hostProperties"]; }

- (KTCopyMediaType)copyMediaOriginals { return [self wrappedIntegerForKey:@"copyMediaOriginals"]; }

- (void)setCopyMediaOriginals:(KTCopyMediaType)copy
{
	[self setWrappedInteger:copy forKey:@"copyMediaOriginals"];
	
	// Record in the defaults
	[[NSUserDefaults standardUserDefaults] setInteger:copy forKey:@"copyMediaOriginals"];
}

- (NSSet *)requiredBundlesIdentifiers
{
	return [self transientValueForKey:@"requiredBundlesIdentifiers" persistentArchivedDataKey:@"requiredBundlesData"];
}

- (void)setRequiredBundlesIdentifiers:(NSSet *)identifiers
{
	[self setTransientValue:identifiers forKey:@"requiredBundlesIdentifiers" persistentArchivedDataKey:@"requiredBundlesData"];
}

- (NSDictionary *)metadata
{
	return [self transientValueForKey:@"metadata" persistentPropertyListKey:@"metadataData"];
}

- (void)setMetadata:(NSDictionary *)metadata
{
	[self setTransientValue:metadata forKey:@"metadata" persistentPropertyListKey:@"metadataData"];
}

#pragma mark -
#pragma mark HTML

/*!	Invoked to fill in the web pages for the meta 'generator' value
 */
- (NSString *)appNameVersion
{
	NSString *version = [NSApplication appVersion];
	
	NSString *applicationName = [NSApplication applicationName];
	if ([[NSApp delegate] isPro])
	{
		applicationName = [applicationName stringByAppendingString:@" Pro"];
	}
	
	return [NSString stringWithFormat:@"%@ %@", applicationName, version];
}

#pragma mark -
#pragma mark Site Menu

- (NSArray *)pagesInSiteMenu
{
	NSArray *result = [self wrappedValueForKey:@"pagesInSiteMenu"];
	if (!result)
	{
		result = [self _pagesInSiteMenu];
		[self setPrimitiveValue:result forKey:@"pagesInSiteMenu"];
	}
	
	OBPOSTCONDITION(result);
	return result;
}

- (NSArray *)_pagesInSiteMenu
{
	// Fetch all the pages qualifying to fit in the Site Menu.
	NSManagedObjectModel *model = [[[self managedObjectContext] persistentStoreCoordinator] managedObjectModel];
	NSFetchRequest *request = [model fetchRequestTemplateForName:@"SiteOutlinePages"];
	
	NSError *error = nil;
	NSArray *unsortedResult = [[self managedObjectContext] executeFetchRequest:request error:&error];
	if (error) {
		[[NSAlert alertWithError:error] runModal];
		return nil;
	}
	
	NSMutableArray *result = [NSMutableArray arrayWithArray:unsortedResult];
	
	
	// Sort the pages according to their index path from root
	[result sortUsingDescriptors:[[self class] _siteMenuSortDescriptors]];
	
	return result;
}

- (void)invalidatePagesInSiteMenuCache
{
	[self setWrappedValue:nil forKey:@"pagesInSiteMenu"];
}

+ (NSArray *)_siteMenuSortDescriptors
{
	static NSArray *result;
	
	if (!result)
	{
		NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"indexPath" ascending:YES];
		result = [[NSArray alloc] initWithObject:sortDescriptor];
		[sortDescriptor release];
	}
	
	return result;
}

#pragma mark -
#pragma mark Quick Look

- (NSString *)pageCount
{
	NSArray *pages = [[self managedObjectContext] allObjectsWithEntityName:@"Page" error:NULL];
	NSString *result = [NSString stringWithFormat:@"%u", [pages count]];
	return result;
}

/*	This could go anywhere really, it's just a convenience method for Quick Look
 */
- (NSString *)currentDate
{
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setDateStyle:NSDateFormatterMediumStyle];
	[formatter setTimeStyle:NSDateFormatterShortStyle];
	NSString *result = [formatter stringFromDate:[NSDate date]];
	
	// Tidy up
	[formatter release];
	return result;
}

@end
