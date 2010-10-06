//
//  KTDocSiteOutlineController.m
//  Marvel
//
//  Created by Terrence Talbot on 1/2/08.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "SVPagesController.h"

#import "KTPage+Internal.h"
#import "SVExternalLink.h"
#import "SVDownloadSiteItem.h"

#import "SVArticle.h"
#import "SVAttributedHTML.h"
#import "KTElementPlugInWrapper.h"
#import "SVLink.h"
#import "SVLinkManager.h"
#import "SVMediaRecord.h"
#import "KTPage+Paths.h"
#import "SVRichText.h"
#import "SVSidebarPageletsController.h"
#import "SVTextAttachment.h"

#import "NSArray+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSObject+Karelia.h"

#import "Debug.h"


NSString *SVPagesControllerDidInsertObjectNotification = @"SVPagesControllerDidInsertObject";


/*	These strings are localizations for case https://karelia.fogbugz.com/default.asp?4736
 *	Not sure when we're going to have time to implement it, so strings are placed here to ensure they are localized.
 *
 *	NSLocalizedString(@"There is already a page with the file name \\U201C%@.\\U201D Do you wish to rename it to \\U201C%@?\\U201D",
					  "Alert message when changing the file name or extension of a page to match an existing file");
 *	NSLocalizedString(@"There are already some pages with the same file name as those you are adding. Do you wish to rename them to be different?",
					  "Alert message when pasting/dropping in pages whose filenames conflict");
 */


@interface SVPagesController ()
- (id)newObjectWithPredecessor:(KTPage *)predecessor allowCollections:(BOOL)allowCollections;
- (void)configurePageAsCollection:(KTPage *)collection;
- (void)didInsertObject:(id)object intoCollection:(KTPage *)collection;
@end


#pragma mark -


@implementation SVPagesController

#pragma mark Creating a Pages Controller

+ (NSArrayController *)controllerWithPagesInCollection:(KTPage *)collection;
{
    NSArrayController *result = [[self alloc] init];
    
    [result bind:NSSortDescriptorsBinding
        toObject:collection
     withKeyPath:@"childItemsSortDescriptors"
         options:nil];
    
    [result setAutomaticallyRearrangesObjects:YES];
    
    [result bind:NSContentSetBinding toObject:collection withKeyPath:@"childItems" options:nil];
    
    return [result autorelease];
}

+ (NSArrayController *)controllerWithPagesToIndexInCollection:(KTPage *)collection;
{
    NSArrayController *result = [self controllerWithPagesInCollection:collection];
    
    // Filter out pages not in index
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"shouldIncludeInIndexes == YES"];
    [result setFilterPredicate:predicate];
    
    return result;
}

#pragma mark Dealloc

- (void) dealloc;
{
    [self setDelegate:nil];
    [super dealloc];
}

#pragma mark Managing Objects

@dynamic entityName;

@synthesize collectionPreset = _presetDict;
@synthesize fileURL = _fileURL;

- (id)newObject
{
    // Figure out the predecessor (which page to inherit properties from)
    KTPage *parent = [[self selectedObjects] lastObject];
    return [self newObjectDestinedForCollection:parent];
}

- (id)newObjectDestinedForCollection:(KTPage *)collection;
{
    // Figure out the predecessor (which page to inherit properties from)
    if (![collection isCollection]) collection = [collection parentPage];
    OBASSERT(collection || ![[self content] count]);    // it's acceptable to have no parent when creating first page
    
    
    KTPage *predecessor = collection;
    NSArray *children = [collection childrenWithSorting:SVCollectionSortByDateCreated
                                          ascending:NO
                                            inIndex:NO];
    
    for (SVSiteItem *aChild in children)
    {
        if ([aChild isKindOfClass:[KTPage class]])
        {
            predecessor = (KTPage *)aChild;
            break;
        }
    }
    
    return [self newObjectWithPredecessor:predecessor allowCollections:YES];
}

- (id)newObjectWithPredecessor:(KTPage *)predecessor allowCollections:(BOOL)allowCollections;
{
    id result = [super newObject];
    
    if ([[self entityName] isEqualToString:@"Page"])
    {
        // Match the basic page properties up to the selection
        [result setMaster:[predecessor master]];
        
        if (predecessor)
        {
            [result setAllowComments:[predecessor allowComments]];
            [result setIncludeTimestamp:[predecessor includeTimestamp]];
        }
        
        // Make the page into a collection if it was requested
        if ([self collectionPreset] && allowCollections) 
        {
            [self configurePageAsCollection:result];
        }
    }
    else if ([[self entityName] isEqualToString:@"ExternalLink"])
    {
        // Guess the link URL
        SVLink *link = [[SVLinkManager sharedLinkManager] guessLink];
        if (link) [result setURL:[NSURL URLWithString:[link URLString]]];
    }
    else if ([[self entityName] isEqualToString:@"File"])
    {
        // Import specified file if possible
        SVMediaRecord *media = nil;
        if ([self fileURL])
        {
            media = [SVMediaRecord mediaWithURL:[self fileURL] entityName:@"FileMedia" insertIntoManagedObjectContext:[self managedObjectContext] error:NULL];
        }
        if (!media)
        {
            NSData *data = [@"" dataUsingEncoding:NSUTF8StringEncoding];
            
            media = [SVMediaRecord
                     mediaWithData:data
                     URL:[NSURL URLWithString:@"x-sandvox-fake-url:///emptystring.html"]
                     entityName:@"FileMedia"
                     insertIntoManagedObjectContext:[self managedObjectContext]];
            
            [media setPreferredFilename:@"Untitled.html"];
            
            
        }
        
        [(SVDownloadSiteItem *)result setMedia:media];
    }
    
    return result;
}

- (void)configurePageAsCollection:(KTPage *)collection;
{
    //  Create a collection. Populate according to the index plug-in (-representedObject) if applicable.
    
    
    NSDictionary *presetDict = [self collectionPreset];
	NSString *identifier = [presetDict objectForKey:@"KTPresetIndexBundleIdentifier"];
	KTElementPlugInWrapper *plugInWrapper = identifier ? [KTElementPlugInWrapper pluginWithIdentifier:identifier] : nil;
	
    NSBundle *indexBundle = [plugInWrapper bundle];
    
    
    // Create the basic collection
    [collection setBool:YES forKey:@"isCollection"]; // Duh!
    [collection setCollectionMaxSyndicatedPagesCount:[NSNumber numberWithInteger:10]];
    
    
    // Now re-set title of page to be the appropriate untitled name
    NSString *englishPresetTitle = [presetDict objectForKey:@"KTPresetUntitled"];
    if (englishPresetTitle)
    {
        NSString *presetTitle = [indexBundle localizedStringForKey:englishPresetTitle value:englishPresetTitle table:nil];
        
        [collection setTitle:presetTitle];
    }
    
    
    // Other settings
    NSDictionary *pageSettings = [presetDict objectForKey:@"KTPageSettings"];
    [collection setValuesForKeysWithDictionary:pageSettings];
    
    
    // Generate a first child page if desired
    /*NSString *firstChildIdentifier = [presetDict valueForKeyPath:@"KTFirstChildSettings.pluginIdentifier"];
    if (firstChildIdentifier && [firstChildIdentifier isKindOfClass:[NSString class]])
    {
        NSMutableDictionary *firstChildProperties =
        [NSMutableDictionary dictionaryWithDictionary:[presetDict objectForKey:@"KTFirstChildSettings"]];
        [firstChildProperties removeObjectForKey:@"pluginIdentifier"];
        
        // Create first child
        KTPage *firstChild = [self newObjectAllowingCollections:NO];
        
        // Insert at right place.
        [collection addChildItem:firstChild];
        [firstChild release];
        
        // Initial properties
        NSEnumerator *propertiesEnumerator = [firstChildProperties keyEnumerator];
        NSString *aKey;
        while (aKey = [propertiesEnumerator nextObject])
        {
            id aProperty = [firstChildProperties objectForKey:aKey];
            if ([aProperty isKindOfClass:[NSString class]])
            {
                aProperty = [indexBundle localizedStringForKey:aProperty value:nil table:@"InfoPlist"];
            }
            
            if ([aKey isEqualToString:@"bodyText"]) // special case
            {
                [[firstChild article] setString:aProperty attachments:nil];
            }
            else
            {
                [firstChild setValue:aProperty forKeyPath:aKey];
            }
        }
    }*/
    
    
    // Any collection with an RSS feed should have an RSS Badge.
    if ([pageSettings boolForKey:@"collectionSyndicationType"])
    {
        // Give weblogs special introductory text
        if ([[presetDict objectForKey:@"KTPresetIndexBundleIdentifier"] isEqualToString:@"sandvox.GeneralIndex"])
        {
            NSString *intro = NSLocalizedString(@"<p>This is a new weblog. You can replace this text with an introduction to your blog, or just delete it if you wish. To add an entry to the weblog, add a new page using the \\U201CPages\\U201D button in the toolbar. For more information on blogging with Sandvox, please have a look through our <a href=\"help:Blogging_with_Sandvox\">help guide</a>.</p>",
                                                "Introductory text for Weblogs");
            
            [[collection article] setString:intro attachments:nil];
        }
    }
    
    
    // Create index and insert
    if (plugInWrapper)
    {
        SVGraphic *index = [[plugInWrapper graphicFactory]
                            insertNewGraphicInManagedObjectContext:[self managedObjectContext]];
        
        NSAttributedString *graphicHTML = [NSAttributedString attributedHTMLStringWithGraphic:index];
        [[index textAttachment] setPlacement:[NSNumber numberWithInt:SVGraphicPlacementInline]];
        [index willInsertIntoPage:collection];
        
        SVRichText *article = [collection article];
        NSMutableAttributedString *html = [[article attributedHTMLString] mutableCopy];
        [html appendAttributedString:graphicHTML];
        [article setAttributedHTMLString:html];
        [html release];
        
        [index didAddToPage:collection];
    }
}

#pragma mark Inserting Objects

- (void) insertObject:(id)object atArrangedObjectIndex:(NSUInteger)index;
{
    [super insertObject:object atArrangedObjectIndex:index];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SVPagesControllerDidInsertObjectNotification object:self];
}

- (void)addObject:(KTPage *)page
{
    // Figure out where to insert the page. i.e. from our selection, what collection should it be made a child of?
    KTPage *parent;
    if ([self delegate])
    {
        parent = [[self delegate] collectionForPagesControllerToInsertInto:self];
    }
    else
    {
        parent = [[self selectedObjects] lastObject];
        if (![parent isCollection]) parent = [parent parentPage];
    }
    
    OBASSERT(parent);
    OBASSERT([parent isCollection]);
    
    
    [self addObject:page toCollection:parent];
}

- (void)addObject:(id)object toCollection:(KTPage *)collection;
{
    OBPRECONDITION(object);
    OBPRECONDITION(collection);
    
    
    // Attach to parent & other relationships
    [object setSite:[collection site] recursively:YES];
    
    
    
    // Add
    [collection addChildItem:object];	// Must use this method to correctly maintain ordering
	
	
    [self didInsertObject: object intoCollection: collection];

    
    
    // Inherit standard pagelets
    if ([object isKindOfClass:[KTPage class]])
    {
        for (SVGraphic *aPagelet in [[collection sidebar] pagelets])
        {
            [SVSidebarPageletsController addPagelet:aPagelet toSidebarOfPage:object];
        }
    }
    
 
	// Include in site menu if appropriate
    if ([collection isRootPage] && [[collection childItems] count] < 7)
    {
        [object setIncludeInSiteMenu:[NSNumber numberWithBool:YES]];
    }
	
    // Do the actual controller-level insertion
    [super addObject:object];
}

- (SVSiteItem *)newObjectFromPropertyList:(id)aPlist destinedForCollection:(KTPage *)collection
{
    [self setEntityName:[aPlist valueForKey:@"entity"]];
    SVSiteItem *result = [self newObjectDestinedForCollection:collection];
    [result awakeFromPropertyList:aPlist];
    return result;
}

- (BOOL)addObjectsFromPasteboard:(NSPasteboard *)pboard toCollection:(KTPage *)collection;
{
    OBPRECONDITION(collection);
    
    if ([[pboard types] containsObject:kKTPagesPboardType])
    {
        NSArray *plists = [pboard propertyListForType:kKTPagesPboardType];
        NSMutableArray *graphics = [NSMutableArray arrayWithCapacity:[plists count]];
        
        for (id aPlist in plists)
        {
            SVSiteItem *item = [self newObjectFromPropertyList:aPlist
                                         destinedForCollection:collection];
            
            if (item)   // might be nil due to invalid plist
            {
                [graphics addObject:item];
                [item release];
            }
        }
        
        if ([graphics count])
        {
            [self addObjects:graphics];
            return YES;
        }
    }
    
    
    BOOL result = NO;
    
    
    // Create graphics for the content
    NSArray *graphics = [SVGraphicFactory graphicsFromPasteboard:pboard
                                  insertIntoManagedObjectContext:[self managedObjectContext]];
    
    for (SVGraphic *aGraphic in graphics)
    {
        // Create pages for each graphic
        [self setEntityName:@"Page"];
        [self setCollectionPreset:nil];
        [self setFileURL:nil];
        
        KTPage *page = [self newObjectDestinedForCollection:collection];
        [page setTitle:[aGraphic title]];
        
        
        // Insert graphic into the page
        [aGraphic willInsertIntoPage:page];
        
        SVRichText *article = [page article];
        NSMutableAttributedString *html = [[article attributedHTMLString] mutableCopy];
        
        NSAttributedString *attachment = [NSAttributedString
                                          attributedHTMLStringWithGraphic:aGraphic];
        
        [html insertAttributedString:attachment atIndex:0];
        [article setAttributedHTMLString:html];
        [html release];
        
        
        // Insert page into the collection
        [self addObject:page toCollection:collection];
        [page release];
        
        [aGraphic didAddToPage:page];
        result = YES;
    }
    
    return result;
}

- (void)moveObject:(id)object toCollection:(KTPage *)collection index:(NSUInteger)index;
{
    [object retain];    // since we're potentially removing it from relationships etc.
    
    KTPage *parent = [object parentPage];
    if (collection != parent)   // no point removing and re-adding a page
    {
        [parent removeChildItem:object];
        [collection addChildItem:object];
        
        [self didInsertObject:object intoCollection:collection];
    }
    
    // Position item too if requested
    if (index != NSOutlineViewDropOnItemIndex &&
        [[collection collectionSortOrder] integerValue] == SVCollectionSortManually)
    {
        [collection moveChild:object toIndex:index];
    }
    
    [object release];
}

- (void)didInsertObject:(id)object intoCollection:(KTPage *)collection;
{
    // Make sure filename is unique within the collection
    NSString *preferredFilename = [object preferredFilename];
    if (![collection isFilenameAvailable:preferredFilename forItem:object])
    {
        [object setFileName:nil];   // needed to fool -suggestedFilename
        NSString *suggestedFilename = [object suggestedFilename];
        [object setFileName:[suggestedFilename stringByDeletingPathExtension]];
    }
}

#pragma mark Accessors

- (NSString *)childrenKeyPath { return @"sortedChildren"; }

#pragma mark KVC

/*	When the user customizes the filename, we want it to become fixed on their choice
 */
- (void)setValue:(id)value forKeyPath:(NSString *)keyPath
{
	[super setValue:value forKeyPath:keyPath];
	
	if ([keyPath isEqualToString:@"selection.fileName"])
	{
		[self setValue:[NSNumber numberWithBool:NO] forKeyPath:@"selection.shouldUpdateFileNameWhenTitleChanges"];
	}
}

#pragma mark Delegate

@synthesize delegate = _delegate;
- (void)setDelegate:(id <SVPagesControllerDelegate>)delegate
{
    if ([_delegate respondsToSelector:@selector(pagesControllerDidInsertObject:)])
    {
        [[NSNotificationCenter defaultCenter] removeObserver:_delegate name:SVPagesControllerDidInsertObjectNotification object:self];
    }
    
    _delegate = delegate;
    
    if ([delegate respondsToSelector:@selector(pagesControllerDidInsertObject:)])
    {
        [[NSNotificationCenter defaultCenter] addObserver:delegate selector:@selector(pagesControllerDidInsertObject:) name:SVPagesControllerDidInsertObjectNotification object:self];
    }
}

@end

