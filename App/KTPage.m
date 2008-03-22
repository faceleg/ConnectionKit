//
//  KTPage.m
//  KTComponents
//
//  Created by Terrence Talbot on 3/10/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "KTPage.h"

#import "ContainsValueTransformer.h"
#import "Debug.h"
#import "KTAbstractIndex.h"
#import "KTAppDelegate.h"
#import "KTDesign.h"
#import "KTDocWindowController.h"
#import "KTDocument.h"
#import "KTElementPlugin.h"
#import "KTManagedObjectContext.h"
#import "KTMaster.h"
#import "NSArray+Karelia.h"
#import "NSAttributedString+Karelia.h"
#import "NSBundle+KTExtensions.h"
#import "NSBundle+Karelia.h"
#import "NSDocumentController+KTExtensions.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSMutableSet+Karelia.h"
#import "NSString+KTExtensions.h"
#import "NSString+Karelia.h"
#import "KTIndexPlugin.h"

@interface NSObject ( RichTextElementDelegateHack )
- (NSString *)richTextHTML;
@end

@interface NSObject ( HTMLElementDelegateHack )
- (NSString *)html;
@end


#pragma mark -


@implementation KTPage

#pragma mark -
#pragma mark Class Methods

/*!	Make sure that changes to titleHTML generate updates for new values of titleText, fileName
*/
+ (void)initialize
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	[self setKeys:[NSArray arrayWithObjects:@"bannerImageID",nil]
		triggerChangeNotificationsForDependentKey:@"bannerImageData"];
	[self setKeys:[NSArray arrayWithObjects:@"headerImage",nil]
		triggerChangeNotificationsForDependentKey:@"headerImageData"];
	
	// Thumbnail
	[self setKeys:[NSArray arrayWithObjects:@"customThumbnail", @"defaultThumbnail", nil]
		triggerChangeNotificationsForDependentKey:@"thumbnail"];

	[self setKeys:[NSArray arrayWithObjects:@"root",nil]
		triggerChangeNotificationsForDependentKey:@"isRoot"];
	[self setKeys:[NSArray arrayWithObjects:@"isRoot",nil]
		triggerChangeNotificationsForDependentKey:@"canEditTitle"];

	[self setKeys:[NSArray arrayWithObjects:@"titleHTML",nil]
		triggerChangeNotificationsForDependentKey:@"titleAttributed"];
	[self setKeys:[NSArray arrayWithObjects:@"titleHTML",nil]
		triggerChangeNotificationsForDependentKey:@"titleText"];
	[self setKeys:[NSArray arrayWithObjects:@"titleHTML",nil]
		triggerChangeNotificationsForDependentKey:@"fileName"];
//	[self setKeys:[NSArray arrayWithObjects: @"isStale", nil]
//        triggerChangeNotificationsForDependentKey: @"staleness"];
	[self setKeys:[NSArray arrayWithObjects: @"keywords", nil]
        triggerChangeNotificationsForDependentKey: @"keywordsAsArray"];
		
	[self setKeys:[NSArray arrayWithObjects: @"collectionSummaryType", nil]
        triggerChangeNotificationsForDependentKey: @"thumbnail"];
	[self setKeys:[NSArray arrayWithObjects: @"collectionSummaryType", nil]
        triggerChangeNotificationsForDependentKey: @"summaryHTML"];
	
	// Sidebars
	[self setKeys:[NSArray arrayWithObjects:@"pagelets", @"includeInheritedSidebar", nil]
		triggerChangeNotificationsForDependentKey:@"allSidebars"];
	
	
	// this is so we get notification of updaates to any properties that affect index type.
	// This is a fake attribute -- we don't actually have this accessor since it' more UI related
	[self setKeys:[NSArray arrayWithObjects:
		@"collectionShowPermanentLink",
		@"collectionHyperlinkPageTitles",
		@"collectionIndexBundleIdentifier",
		@"collectionSyndicate", 
		@"collectionMaxIndexItems", 
		@"collectionSortOrder", 
		nil]
        triggerChangeNotificationsForDependentKey: @"indexPresetDictionary"];
	
	
	
	// Paths
	[self setKeys:[NSArray arrayWithObject:@"customFileExtension"]
		triggerChangeNotificationsForDependentKey:@"fileExtension"];
	
	
	// Register transformers
	NSSet *collectionTypes = [NSSet setWithObjects:[NSNumber numberWithInt:KTSummarizeRecentList],
												   [NSNumber numberWithInt:KTSummarizeAlphabeticalList],
												   nil];
	
	NSValueTransformer *transformer = [[ContainsValueTransformer alloc] initWithComparisonObjects:collectionTypes];
	[NSValueTransformer setValueTransformer:transformer forName:@"KTCollectionSummaryTypeIsTitleList"];
	[transformer release];
	
	[pool release];
}

+ (NSString *)entityName { return @"Page"; }

+ (NSString *)extensiblePropertiesDataKey { return @"extensiblePropertiesData"; }

+ (KTPage *)rootPageWithDocument:(KTDocument *)aDocument bundle:(NSBundle *)aBundle
{
	NSParameterAssert([aBundle bundleIdentifier]);
	
	id root = [NSEntityDescription insertNewObjectForEntityForName:@"Root" 
											inManagedObjectContext:[aDocument managedObjectContext]];
	
	if ( nil != root )
	{
		[root setDocument:aDocument];
		[root setValue:[aDocument documentInfo] forKey:@"documentInfo"];	// point to yourself
		
		[root setValue:[aBundle bundleIdentifier] forKey:@"pluginIdentifier"];
		[root setBool:YES forKey:@"isCollection"];	// root is automatically a collection
		[root setBool:NO forKey:@"allowComments"];
		[root awakeFromBundleAsNewlyCreatedObject:YES];
	}

	return root;
}

+ (KTPage *)pageWithParent:(KTPage *)aParent plugin:(KTElementPlugin *)aPlugin insertIntoManagedObjectContext:(KTManagedObjectContext *)aContext
{
	NSParameterAssert(aParent);		NSParameterAssert([[aPlugin bundle] bundleIdentifier]);

	// Create the page
	id page = [NSEntityDescription insertNewObjectForEntityForName:@"Page" inManagedObjectContext:aContext];
	[page setValue:[[aPlugin bundle] bundleIdentifier] forKey:@"pluginIdentifier"];
	
	
	// Load properties from parent/sibling
	KTPage *previousPage = aParent;
	NSArray *children = [aParent childrenWithSorting:KTCollectionSortLatestAtTop];
	if ([children count] > 0)
	{
		previousPage = [children firstObject];
	}
	
	[page setBool:[previousPage boolForKey:@"allowComments"] forKey:@"allowComments"];
	[page setBool:[previousPage boolForKey:@"includeTimestamp"] forKey:@"includeTimestamp"];
	
	
	// Attach the page to its parent & other relationships
	
	[page setValue:[aParent master] forKey:@"master"];
	
	NSAssert((nil != [aParent root]), @"parent page's root should not be nil");
	[aParent addPage:page];	// Must use this method to correctly maintain ordering
	[page setValue:[aParent valueForKeyPath:@"documentInfo"] forKey:@"documentInfo"];
	
	[page awakeFromBundleAsNewlyCreatedObject:YES];		// now it should be real data

	return page;
}

+ (KTPage *)pageWithParent:(KTPage *)aParent
				dataSourceDictionary:(NSDictionary *)aDictionary
	  insertIntoManagedObjectContext:(KTManagedObjectContext *)aContext;
{
	NSParameterAssert(nil != aParent);

	KTElementPlugin *plugin = [aDictionary objectForKey:kKTDataSourcePlugin];
	NSAssert((nil != plugin), @"drag dictionary does not have a real plugin");
	
	id page = [self pageWithParent:aParent plugin:plugin insertIntoManagedObjectContext:aContext];
	
	// anything else to do with the drag source dictionary other than to get the bundle?
	// should the delegate be passed the dictionary and have an opportunity to use it?
	[page awakeFromDragWithDictionary:aDictionary];
	
	return page;
}

#pragma mark -
#pragma mark Awake

/*!	Early initialization.  Note that we don't know our bundle yet!  Use awakeFromBundle for later init.
*/
- (void)awakeFromInsert
{
	[super awakeFromInsert];
		
	// attributes
	NSDate *now = [NSDate date];
	[self setValue:now forKey:@"creationDate"];
	[self setValue:now forKey:@"lastModificationDate"];
	
	[self setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"MaximumTitlesInCollectionSummary"]
			forKey:@"collectionSummaryMaxPages"];
}

/*!	Initialization that happens after awakeFromFetch or awakeFromInsert
*/
- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewlyCreatedObject
{
	if ( isNewlyCreatedObject )
	{
		// Initialize this required value from the info dictionary
		NSNumber *includeSidebar = [[self plugin] pluginPropertyForKey:@"KTPageShowSidebar"];
		[self setValue:includeSidebar forKey:@"includeSidebar"];
			
		NSString *titleText = [[self plugin] pluginPropertyForKey:@"KTPageUntitledName"];
		[self setTitleText:titleText];
		// Note: there won't be a site title set for a newly created object.
		
		KTPage *parent = [self parent];
		// Set includeInSiteMenu if this page's parent is root, and not too many siblings
		if (nil != parent && [parent isRoot] && [[parent valueForKey:@"children"] count] < 7)
		{
			[self setIncludeInSiteMenu:YES];
		}
	}
	else	// Loading from disk
	{
		NSString *identifier = [self valueForKey:@"collectionIndexBundleIdentifier"];
		if (nil != identifier)
		{
			KTIndexPlugin *plugin = [KTIndexPlugin pluginWithIdentifier:identifier];
			Class indexToAllocate = [NSBundle principalClassForBundle:[plugin bundle]];
			KTAbstractIndex *theIndex = [[((KTAbstractIndex *)[indexToAllocate alloc]) initWithPage:self plugin:plugin] autorelease];
			[self setIndex:theIndex];
		}
		
		
		// set transient. (for loading from disk -- already set if we created object)
		NSString *html = [self valueForKey:@"titleHTML"];
		if (nil != html)
		{
			NSString *flattenedTitle = [html flattenHTML];
			NSAttributedString *attrString = [NSAttributedString systemFontStringWithString:flattenedTitle];
			[self setPrimitiveValue:[attrString archivableData] forKey:@"titleAttributed"];
		}
	}
		
	[self setNewPage:isNewlyCreatedObject];		// for benefit of webkit editing only
	
	
	// Default values pulled from the plugin's Info.plist
	[self setDisableComments:[[[self plugin] pluginPropertyForKey:@"KTPageDisableComments"] boolValue]];
	[self setSidebarChangeable:[[[self plugin] pluginPropertyForKey:@"KTPageSidebarChangeable"] boolValue]];
	
	
	// I moved this below the above, in order to give the delegates a chance to override the
	// defaults.
	[super awakeFromBundleAsNewlyCreatedObject:isNewlyCreatedObject];
}

- (void)awakeFromDragWithDictionary:(NSDictionary *)aDictionary
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[super awakeFromDragWithDictionary:aDictionary];
    NSString *title = [aDictionary valueForKey:kKTDataSourceTitle];
    if ( nil == title )
	{
		// No title specified; use file name (minus extension)
		NSFileManager *fm = [NSFileManager defaultManager];
		title = [[fm displayNameAtPath:[aDictionary valueForKey:kKTDataSourceFileName]] stringByDeletingPathExtension];
	}
	if (nil != title)
	{
		[self setTitleText:title];
	}
	if ([defaults boolForKey:@"SetDateFromSourceMaterial"])
	{
		if (nil != [aDictionary objectForKey:kKTDataSourceCreationDate])	// date set from drag source?
		{
			[self setValue:[aDictionary objectForKey:kKTDataSourceCreationDate] forKey:@"creationDate"];
		}
		else if (nil != [aDictionary objectForKey:kKTDataSourceFilePath])
		{
			// Get creation date from file if it's not specified explicitly
			NSDictionary *fileAttrs = [[NSFileManager defaultManager]
				fileAttributesAtPath:[aDictionary objectForKey:kKTDataSourceFilePath]
						traverseLink:YES];
			NSDate *date = [fileAttrs objectForKey:NSFileCreationDate];
			[self setValue:date forKey:@"creationDate"];
		}
	}
}

#pragma mark -
#pragma mark Dealloc

- (void)dealloc
{
    // release ivars
	[self setDocument:nil];
    [mySortedChildrenCache release];
	
    [super dealloc];
}

#pragma mark -
#pragma mark Master

- (KTMaster *)master { return [self wrappedValueForKey:@"master"]; }

/*	The published path to the design directory relative to the receiver.
 */
- (NSString *)designDirectoryPath
{
	KTDesign *design = [[self master] design];
	NSString *designPath = [@"/" stringByAppendingString:[design remotePath]];
	
	NSString *pagePath = [@"/" stringByAppendingString:[self pathRelativeToSite]];
	
	NSString *result = [designPath pathRelativeTo:pagePath];
	return result;
}

#pragma mark -
#pragma mark contextual menu validation

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	//LOG((@"asking page to validate menu item %@", [menuItem title]));
    if ( [menuItem action] == @selector(movePageletToSidebar:) )
    {
        return YES;
    }
    else if ( [menuItem action] == @selector(movePageletToCallouts:) )
    {
        return YES;
    }
    
    return YES;
}

#pragma mark -
#pragma mark Media

/*	Each page adds a number of possible required media to the default. e.g. thumbnail
 */
- (NSSet *)requiredMediaIdentifiers
{
	NSMutableSet *result = [NSMutableSet setWithSet:[super requiredMediaIdentifiers]];
	
	// Inclue our thumbnail and site outline image
	[result addObjectIgnoringNil:[self valueForKey:@"thumbnailMediaIdentifier"]];
	[result addObjectIgnoringNil:[self valueForKey:@"customSiteOutlineIconIdentifier"]];
	
	// Include anything our index requires?
	NSSet *indexMediaIDs = [[self index] requiredMediaIdentifiers];
	if (indexMediaIDs)
	{
		[result unionSet:indexMediaIDs];
	}
	
	return result;
}

#pragma mark -
#pragma mark Archiving

+ (id)objectWithArchivedIdentifier:(NSString *)identifier inDocument:(KTDocument *)document
{
	id result = [KTAbstractPage pageWithUniqueID:identifier inManagedObjectContext:[document managedObjectContext]];
	return result;
}

- (NSString *)archiveIdentifier { return [self uniqueID]; }

#pragma mark -
#pragma mark Inspector

/*!	True if this page type should put the inspector in the third inspector segment -- use sparingly.
*/
- (BOOL)separateInspectorSegment
{
	return [[[self plugin] pluginPropertyForKey:@"KTPageSeparateInspectorSegment"] boolValue];
}

#pragma mark -
#pragma mark Debugging

// More human-readable description
- (NSString *)shortDescription
{
	return [NSString stringWithFormat:@"%@ <%p> %@ : %@ %@ %@", [self class], self, ([self isRoot] ? @"(root)" : ([self isCollection] ? @"(collection)" : @"")),
		[self fileName], [self wrappedValueForKey:@"uniqueID"], [self wrappedValueForKey:@"pluginIdentifier"]];
}

@end
