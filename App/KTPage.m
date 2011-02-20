//
//  KTPage.m
//  KTComponents
//
//  Created by Terrence Talbot on 3/10/05.
//  Copyright 2005-2011 Karelia Software. All rights reserved.
//

#import "KTPage+Paths.h"

#import "SVArticle.h"
#import "KTDesign.h"
#import "KTDocWindowController.h"
#import "KTDocument.h"
#import "SVGraphic.h"
#import "KTMaster.h"
#import "SVMediaRecord.h"
#import "SVPageTitle.h"
#import "SVPagesController.h"
#import "SVTextAttachment.h"

#import "NSBundle+KTExtensions.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSString+KTExtensions.h"

#import "NSArray+Karelia.h"
#import "NSAttributedString+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSError+Karelia.h"
#import "NSSet+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"
#import "NSURL+Karelia.h"
#import "KSContainsObjectValueTransformer.h"
#import "KTSite.h"

#import "Debug.h"


@interface KTPage ()
@property(nonatomic, retain, readwrite) SVSidebar *sidebar;
@property(nonatomic, retain, readwrite) SVArticle *article;
@end


#pragma mark -


@implementation KTPage

#ifdef DEBUG
- (NSString *)description
{
	if ([NSUserName() isEqualToString:@"dwood"])
	{
		return [NSString stringWithFormat:@"%p %@", self, [self title]];
	}
	return [super description];
}
#endif


#pragma mark Class Methods

/*!	Make sure that changes to titleHTML generate updates for new values of title, fileName
*/
+ (void)initialize
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    // Register transformers
	NSSet *collectionTypes = [NSSet setWithObjects:[NSNumber numberWithInt:KTSummarizeRecentList],
												   [NSNumber numberWithInt:KTSummarizeAlphabeticalList],
												   nil];
	
	NSValueTransformer *transformer = [[KSContainsObjectValueTransformer alloc] initWithComparisonObjects:collectionTypes];
	[NSValueTransformer setValueTransformer:transformer forName:@"KTCollectionSummaryTypeIsTitleList"];
	[transformer release];
	
	
	[pool release];
}

+ (NSSet *)keyPathsForValuesAffectingSummaryHTML
{
    return [NSSet setWithObject:@"collectionSummaryType"];
}

+ (NSString *)entityName { return @"Page"; }

#pragma mark Awake

/*!	Early initialization.  Note that we don't know our bundle yet!  Use awakeFromBundle for later init.
*/
- (void)awakeFromInsert
{
	[super awakeFromInsert];
    
    
    // Create a corresponding sidebar
    SVSidebar *sidebar = [NSEntityDescription insertNewObjectForEntityForName:@"Sidebar"
                                                       inManagedObjectContext:[self managedObjectContext]];
    
    [self setSidebar:sidebar];
	
    
    // Placeholder text
    [self setTitle:NSLocalizedString(@"Untitled", "placeholder text")];
	
    
    // Body text. Give it a starting paragraph
    SVArticle *body = [SVArticle insertPageBodyIntoManagedObjectContext:[self managedObjectContext]];
    [body setString:@"<p><br /></p>"];
    [self setArticle:body];
    
    
	id maxTitles = [[NSUserDefaults standardUserDefaults] objectForKey:@"MaximumTitlesInCollectionSummary"];
    if ([maxTitles isKindOfClass:[NSNumber class]])
    {
        [self setPrimitiveValue:maxTitles forKey:@"collectionMaxSyndicatedPagesCount"];
    }
    
    [self setPrimitiveValue:@"index.rss" forKey:@"RSSFileName"];
    
    
    // Code Injection
    KTCodeInjection *codeInjection = [NSEntityDescription insertNewObjectForEntityForName:@"PageCodeInjection"
                                                                   inManagedObjectContext:[self managedObjectContext]];
    [self setValue:codeInjection forKey:@"codeInjection"];
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

- (BOOL)showsTitle;
{
    return ![[[self titleBox] hidden] boolValue];
}

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

- (void)writeTitle:(id <SVPlugInContext>)context;   // uses rich txt/html when available
{
    [context writeHTMLString:[self titleHTMLString]];
}

- (void)addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)context;
{
    // Make sure .titleBox is already faulted in before observing title. #108418
    if ([keyPath isEqualToString:@"title"] && [self isFault])
    {
        [self willAccessValueForKey:nil];
    }
    
    [super addObserver:observer forKeyPath:keyPath options:options context:context];
}

#pragma mark Body

@dynamic article;

- (void)writeContent:(SVHTMLContext *)context recursively:(BOOL)recursive;
{
    [super writeContent:context recursively:recursive];
    
    
    // Custom window title if specified
    NSString *windowTitle = [self windowTitle];
    if (windowTitle)
    {
        [context writeText:windowTitle];
        [context writeString:@"\n"];
    }
    
    // Custom meta description if specified
    NSString *meta = [self metaDescription];
    if (meta)
    {
        [context writeText:meta];
        [context writeString:@"\n"];
    }
    
    // Body
    [[self article] writeText:context];
    
    // Children
    if (recursive)
    {
        for (SVSiteItem *anItem in [self sortedChildren])
        {
            [anItem writeContent:context recursively:recursive];
        }
    }
}

@dynamic masterIdentifier;

#pragma mark Site/Master

- (void)setSite:(KTSite *)site recursively:(BOOL)recursive;
{
    [super setSite:site recursively:recursive];
    
    if (recursive)
    {
        for (SVSiteItem *anItem in [self childItems])
        {
            [anItem setSite:site recursively:recursive];
        }
    }
}

@dynamic master;

- (void)setMaster:(KTMaster *)master recursive:(BOOL)recursive; // calls -didAddToPage: on graphics
{
    [self setMaster:master];
    
    // When adding via the pboard, graphics need to fit within the page
    NSSet *graphics = [[[self article] attachments] valueForKey:@"graphic"];
    [graphics makeObjectsPerformSelector:@selector(didAddToPage:) withObject:self];
    
    // Carry on down the tree
    if (recursive)
    {
        for (id anItem in [self childItems])
        {
            if ([anItem respondsToSelector:@selector(setMaster:recursive:)])
            {
                [anItem setMaster:master recursive:recursive];
            }
        }
    }
}

#pragma mark Properties

@dynamic sidebar;
@dynamic showSidebar;

#pragma mark Master

- (NSString *)language { return [[self master] language]; }
+ (NSSet *)keyPathsForValuesAffectingLanguage;
{
    return [NSSet setWithObject:@"master.language"];
}

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
        [self setModificationDate:[NSDate date]];
    }
}

#pragma mark Paths

/*	A custom file extension of nil signifies that the value should be taken from the user defaults.
 */
- (NSString *)customPathExtension { return [self wrappedValueForKey:@"customFileExtension"]; }

- (void)setCustomPathExtension:(NSString *)extension
{
	[self setWrappedValue:extension forKey:@"customFileExtension"];
	[self recursivelyInvalidateURL:NO];
}

// Derived
- (NSString *)customIndexAndPathExtension
{
	NSString *result = [self wrappedValueForKey:@"customFileExtension"];
	if (result)
	{
		NSString *indexFileName = [[[self site] hostProperties] valueForKey:@"htmlIndexBaseName"];
		result = [indexFileName stringByAppendingPathExtension:result];
	}
	return result;
}

- (void)setCustomIndexAndPathExtension:(NSString *)indexAndExtension
{
	NSString *extensionOnly = [indexAndExtension pathExtension];
	[self setCustomPathExtension:extensionOnly];
}

/*	KTAbstractPage doesn't support recursive operations, so we do instead
 */
- (void)recursivelyInvalidateURL:(BOOL)recursive
{
	[self willChangeValueForKey:@"URL"];
	[self setPrimitiveValue:nil forKey:@"URL"];
    
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
            
            [anItem recursivelyInvalidateURL:YES];
		}
	}
    
	[self didChangeValueForKey:@"URL"];
}

#pragma mark Thumbnail

- (BOOL)writeThumbnailImage:(SVHTMLContext *)context
                       type:(SVThumbnailType)type
                      width:(NSUInteger)width
                     height:(NSUInteger)height
                    options:(SVThumbnailOptions)options;
{
    switch (type)
    {
        case SVThumbnailTypePickFromPage:
        {
            // Grab thumbnail from appropriate graphic and write that
            SVGraphic *source = [self thumbnailSourceGraphic];
            if ([source imageRepresentation])
            {
                if (!(options & SVThumbnailDryRun))
                {
                    [source writeThumbnailImage:context width:width height:height options:options];
                }
                return YES;
            }
            else
            {
                // Write placeholder if desired
                return [super writeThumbnailImage:context type:type width:width height:height options:options];
            }
        }
            
        case SVThumbnailTypeFirstChildItem:
        {
            // Just ask the page in question to write its thumbnail
            NSArrayController *controller = [SVPagesController controllerWithPagesToIndexInCollection:self];
            
            SVSiteItem *page = [[controller arrangedObjects] firstObjectKS];
            [context addDependencyOnObject:controller keyPath:@"arrangedObjects"];
            
            return [page writeThumbnailImage:context
                                        type:[[page thumbnailType] intValue]
                                       width:width
                                      height:height
                                     options:options];
        }
            
        case SVThumbnailTypeLastChildItem:
        {
            // Just ask the page in question to write its thumbnail
            NSArrayController *controller = [SVPagesController controllerWithPagesToIndexInCollection:self];
            
            SVSiteItem *page = [[controller arrangedObjects] lastObject];
            [context addDependencyOnObject:controller keyPath:@"arrangedObjects"];
            
            return [page writeThumbnailImage:context
                                        type:[[page thumbnailType] intValue]
                                       width:width
                                      height:height
                                      options:options];
        }
            
        default:
            // Hand off to super for custom/no thumbnail
            return [super writeThumbnailImage:context
                                         type:type
                                        width:width
                                       height:height
                                      options:options];
    }
}

@dynamic thumbnailSourceGraphic;

- (void)guessThumbnailSourceGraphic;
{
    SVGraphic *thumbnailGraphic = [[[[self article] orderedAttachments] firstObjectKS] graphic];
    [self setThumbnailSourceGraphic:thumbnailGraphic];
}

- (BOOL)validateThumbnailType:(NSNumber **)outType error:(NSError **)error;
{
    SVThumbnailType maxType = ([self isCollection] ? 
                               SVThumbnailTypeLastChildItem : 
                               SVThumbnailTypePickFromPage);
    
    BOOL result = ([*outType intValue] <= maxType);
    if (!result && error)
    {
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSValidationNumberTooLargeError localizedDescription:@"thumbnailType is too large for this type of page"];
    }
    
    return result;
}

- (id)imageRepresentation;
{
    id result;
    if ([[self thumbnailType] integerValue] == SVThumbnailTypePickFromPage)
    {
        result = [[self thumbnailSourceGraphic] imageRepresentation];
    }
    else
    {
        result = [super imageRepresentation];
    }
    
    // Fallback to regular icon
    if (!result)
    {
        result = [NSImage imageNamed:@"newPage.tiff"];
    }
    
    return result;
}

- (NSString *)imageRepresentationType;
{
    id result = nil;
    if ([[self thumbnailType] integerValue] == SVThumbnailTypePickFromPage)
    {
        SVGraphic *graphic = [self thumbnailSourceGraphic];
        if ([graphic imageRepresentation])
        {
            result = [graphic imageRepresentationType];
        }
    }
    else
    {
        result = [super imageRepresentationType];
    }
    
    // Fallback to regular icon
    if (!result)
    {
        result = IKImageBrowserNSImageRepresentationType;
    }
    
    return result;
}

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
