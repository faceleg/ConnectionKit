//
//  KTPage.m
//  KTComponents
//
//  Created by Terrence Talbot on 3/10/05.
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import "KTPage+Internal.h"

#import "KSContainsObjectValueTransformer.h"
#import "Debug.h"
#import "KTAbstractIndex.h"
#import "SVBody.h"
#import "SVBodyParagraph.h"
#import "KTDesign.h"
#import "KTDocWindowController.h"
#import "KTDocument.h"
#import "KTIndexPlugin.h"
#import "KTMaster.h"
#import "SVPageTitle.h"

#import "NSArray+Karelia.h"
#import "NSAttributedString+Karelia.h"
#import "NSBundle+KTExtensions.h"
#import "NSBundle+Karelia.h"
#import "NSDocumentController+KTExtensions.h"
#import "NSError+Karelia.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSSet+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSString+KTExtensions.h"
#import "NSString+Karelia.h"


@interface KTPage ()
@property(nonatomic, retain, readwrite) SVBody *body;
@end


#pragma mark -


@implementation KTPage

#pragma mark Class Methods

/*!	Make sure that changes to titleHTML generate updates for new values of title, fileName
*/
+ (void)initialize
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    // this is so we get notification of updaates to any properties that affect index type.
	// This is a fake attribute -- we don't actually have this accessor since it's more UI related
	[self setKeys:[NSArray arrayWithObjects:
		@"collectionShowPermanentLink",
		@"collectionHyperlinkPageTitles",
		@"collectionIndexBundleIdentifier",
		@"collectionSyndicate", 
		@"collectionMaxIndexItems", 
		@"collectionSortOrder", 
		nil]
        triggerChangeNotificationsForDependentKey: @"indexPresetDictionary"];
	
	
	
	// Register transformers
	NSSet *collectionTypes = [NSSet setWithObjects:[NSNumber numberWithInt:KTSummarizeRecentList],
												   [NSNumber numberWithInt:KTSummarizeAlphabeticalList],
												   nil];
	
	NSValueTransformer *transformer = [[KSContainsObjectValueTransformer alloc] initWithComparisonObjects:collectionTypes];
	[NSValueTransformer setValueTransformer:transformer forName:@"KTCollectionSummaryTypeIsTitleList"];
	[transformer release];
	
	
	[pool release];
}

+ (NSSet *)keyPathsForValuesAffectingIsRoot
{
    return [NSSet setWithObject:@"root"];
}

+ (NSSet *)keyPathsForValuesAffectingSummaryHTML
{
    return [NSSet setWithObject:@"collectionSummaryType"];
}

+ (NSString *)entityName { return @"Page"; }

#pragma mark -
#pragma mark Initialisation

/*	Private support method that creates a generic, blank page.
 *	It gets created either by unarchiving or the user creating a new page.
 */
+ (KTPage *)_insertNewPageWithParent:(KTPage *)parent
{
	OBPRECONDITION([parent managedObjectContext]);
	
	
	// Create the page
	KTPage *result = [NSEntityDescription insertNewObjectForEntityForName:@"Page"
                                                   inManagedObjectContext:[parent managedObjectContext]];
	
	
	// Attach to parent & other relationships
	[result setMaster:[parent master]];
	[result setSite:[parent valueForKeyPath:@"site"]];
	[parent addChildItem:result];	// Must use this method to correctly maintain ordering
	
	return result;
}

+ (KTPage *)insertNewPageWithParent:(KTPage *)aParent;
{
	// Figure out nearest sibling/parent
    KTPage *predecessor = aParent;
	NSArray *children = [aParent childrenWithSorting:SVCollectionSortByDateModified inIndex:NO];
	if ([children count] > 0)
	{
		predecessor = [children firstObjectKS];
	}
	
	
    // Create the page
	KTPage *page = [self _insertNewPageWithParent:aParent];
	
	
	// Load properties from parent/sibling
	[page setAllowComments:[predecessor allowComments]];
	[page setIncludeTimestamp:[predecessor includeTimestamp]];
	
	
	// And we're finally ready to let normal initalisation take over
	[page awakeFromBundleAsNewlyCreatedObject:YES];

	return page;
}

+ (KTPage *)pageWithParent:(KTPage *)aParent
				dataSourceDictionary:(NSDictionary *)aDictionary
	  insertIntoManagedObjectContext:(NSManagedObjectContext *)aContext;
{
	OBPRECONDITION(nil != aParent);

	id page = [self insertNewPageWithParent:aParent];
	
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
	
    
    // Placeholder text
    [self setTitle:NSLocalizedString(@"Untitled", "placeholder text")];
	
    
    // Body text. Give it a starting paragraph
    SVBody *body = [SVBody insertPageBodyIntoManagedObjectContext:[self managedObjectContext]];
    [self setBody:body];
    
    SVBodyParagraph *paragraph = [NSEntityDescription insertNewObjectForEntityForName:@"BodyParagraph" inManagedObjectContext:[self managedObjectContext]];
    [paragraph setTagName:@"p"];
    [paragraph setArchiveString:@"Lorem ipsum..."];
    [paragraph setSortKey:[NSNumber numberWithInt:0]];
    [body addElement:paragraph];
    
    
	id maxTitles = [[NSUserDefaults standardUserDefaults] objectForKey:@"MaximumTitlesInCollectionSummary"];
    if ([maxTitles isKindOfClass:[NSNumber class]])
    {
        [self setPrimitiveValue:maxTitles forKey:@"collectionSummaryMaxPages"];
    }
    
    [self setPrimitiveValue:[[NSUserDefaults standardUserDefaults] stringForKey:@"RSSFileName"]
                     forKey:@"RSSFileName"];
    
    
    // Code Injection
    KTCodeInjection *codeInjection = [NSEntityDescription insertNewObjectForEntityForName:@"PageCodeInjection"
                                                                   inManagedObjectContext:[self managedObjectContext]];
    [self setValue:codeInjection forKey:@"codeInjection"];
}

/*!	Initialization that happens after awakeFromFetch or awakeFromInsert
*/
- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewlyCreatedObject
{
	if ( isNewlyCreatedObject )
	{
		KTPage *parent = [self parentPage];
		// Set includeInSiteMenu if this page's parent is root, and not too many siblings
		if (nil != parent && [parent isRoot] && [[parent childItems] count] < 7)
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
			Class indexToAllocate = [[plugin bundle] principalClassIncludingOtherLoadedBundles:YES];
			KTAbstractIndex *theIndex = [[((KTAbstractIndex *)[indexToAllocate alloc]) initWithPage:self plugin:plugin] autorelease];
			[self setIndex:theIndex];
		}
	}
		
	[self setNewPage:isNewlyCreatedObject];		// for benefit of webkit editing only
}

- (void)awakeFromDragWithDictionary:(NSDictionary *)aDictionary
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *title = [aDictionary valueForKey:kKTDataSourceTitle];
    if ( nil == title )
	{
		// No title specified; use file name (minus extension)
		NSFileManager *fm = [NSFileManager defaultManager];
		title = [[fm displayNameAtPath:[aDictionary valueForKey:kKTDataSourceFileName]] stringByDeletingPathExtension];
	}
	if (nil != title)
	{
		NSString *titleHTML = [[self titleBox] textHTMLString];
		if (nil == titleHTML || [titleHTML isEqualToString:@""])
		{
			[self setTitle:title];
		}
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

- (void)awakeFromFetch
{
	[super awakeFromFetch];
	[self awakeFromBundleAsNewlyCreatedObject:NO];
}

#pragma mark Title

@dynamic titleBox;

- (NSString *)title
{
    return [[self titleBox] text];
}
- (void)setTitle:(NSString *)title;
{
    SVPageTitle *titleBox = [self titleBox];
    if (!titleBox)
    {
        titleBox = [NSEntityDescription insertNewObjectForEntityForName:@"PageTitle" inManagedObjectContext:[self managedObjectContext]];
        [self setTitleBox:titleBox];
    }
    [titleBox setText:title];
}
+ (NSSet *)keyPathsForValuesAffectingTitle { return [NSSet setWithObject:@"titleBox.text"]; }

// For bindings.  We can edit title if we aren't root;
- (BOOL)canEditTitle
{
	BOOL result = ![self isRoot];
	return result;
}

- (NSString *)titleHTMLString
{
    return [[self titleBox] textHTMLString];
}

- (NSString *)titleString;
{
	return [[self titleBox] text];
}

#pragma mark Body

@dynamic body;

#pragma mark Properties

- (KTMaster *)master { return [self wrappedValueForKey:@"master"]; }

@dynamic showSidebar;

#pragma mark Dates

/*  When updating one of the plug-in's properties, also update the modification date
 */
- (void)setValue:(id)value forUndefinedKey:(NSString *)key
{
    [super setValue:value forUndefinedKey:key];
    
    
    static NSSet *excludedKeys;
    if (!excludedKeys)
    {
        excludedKeys = [[NSSet alloc] initWithObjects:
                        @"shouldUpdateFileNameWhenTitleChanges",
                        @"windowTitle",
                        @"metaDescription",
                        @"publishedDataDigest",
                        nil];
    }
    
    if (![excludedKeys containsObject:key])
    {
        [self setValue:[NSDate date] forKey:@"lastModificationDate"];
    }
}

#pragma mark Paths

/*	If set, returns the custom file extension. Otherwise, takes the value from the defaults
 */
- (NSString *)pathExtension
{
	NSString *result = [self customPathExtension];
	
	if (!result) result = [super pathExtension];
	
    OBPOSTCONDITION(result);
    return result;
}

/*	Implemented just to stop anyone accidentally calling it.
 */
- (void)setPathExtension:(NSString *)extension
{
	[NSException raise:NSInternalInconsistencyException
			    format:@"-%@ is not supported. Please use -setCustomFileExtension instead.", NSStringFromSelector(_cmd)];
}

+ (NSSet *)keyPathsForValuesAffectingPathExtension
{
    return [NSSet setWithObjects:@"customFileExtension", @"defaultFileExtension", nil];
}

/*	A custom file extension of nil signifies that the value should be taken from the user defaults.
 */
- (NSString *)customPathExtension { return [self wrappedValueForKey:@"customFileExtension"]; }

- (void)setCustomPathExtension:(NSString *)extension
{
	[self setWrappedValue:extension forKey:@"customFileExtension"];
	[self recursivelyInvalidateURL:NO];
}

/*	KTAbstractPage doesn't support recursive operations, so we do instead
 */
- (void)recursivelyInvalidateURL:(BOOL)recursive
{
	[super recursivelyInvalidateURL:recursive];
	
	// Children should be affected last since they depend on parents' path
	if (recursive)
	{
		NSSet *children = [self childItems];
		for (SVSiteItem *anItem in children)
		{
			OBASSERT(![self isDescendantOfItem:anItem]); // lots of assertions for #44139
            OBASSERT(anItem != self);
            OBASSERT(![[anItem childItems] containsObject:self]);
            
            [[anItem pageRepresentation] recursivelyInvalidateURL:YES];
		}
		
		NSSet *archives = [self archivePages];
		for (KTArchivePage *aPage in archives)
		{
			OBASSERT(![aPage isKindOfClass:[KTPage class]]);
            [aPage recursivelyInvalidateURL:YES];
		}
	}
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

#pragma mark Editing

- (KTPage *)pageRepresentation { return self; }

#pragma mark Debugging

// More human-readable description
- (NSString *)shortDescription
{
	return [NSString stringWithFormat:@"%@ <%p> %@ : %@ %@ %@", [self class], self, ([self isRoot] ? @"(root)" : ([self isCollection] ? @"(collection)" : @"")),
		[self fileName], [self wrappedValueForKey:@"uniqueID"], [self wrappedValueForKey:@"pluginIdentifier"]];
}

@end
