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
#import "SVPageTemplate.h"
#import "SVRichText.h"
#import "SVSidebarPageletsController.h"
#import "SVTextAttachment.h"

#import "NSManagedObjectContext+KTExtensions.h"

#import "NSArray+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSObject+Karelia.h"

#import "KSWebLocationPasteboardUtilities.h"

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

@property(nonatomic, retain, readwrite) SVPageTemplate *pageTemplate;
@property(nonatomic, copy, readwrite) NSURL *objectURL;

- (id)newObjectWithPredecessor:(KTPage *)predecessor followTemplate:(BOOL)allowCollections;
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

#pragma mark Managing Content

- (void)add:(id)sender;
{
    [self commitEditingWithDelegate:self
                  didCommitSelector:@selector(controller:didCommitBeforeAdding:contextInfo:)
                        contextInfo:NULL];
}

- (void)controller:(SVPagesController *)controller didCommitBeforeAdding:(BOOL)didCommit contextInfo:(void  *)contextInfo
{
    if (didCommit)
    {
        if ([[self entityName] isEqualToString:@"ExternalLink"] && ![self objectURL])
        {
            // Guess URL before continuing
            SVLink *link = [[SVLinkManager sharedLinkManager] guessLink];
            if ([link URLString]) [self setObjectURL:[NSURL URLWithString:[link URLString]]];
        }
        
        
        SVSiteItem *item = [self newObject];
        if ([[item childItems] count] == 1)
        {
            // Select the first child, rather than item itself
            BOOL select = [self selectsInsertedObjects];
            [self setSelectsInsertedObjects:NO];
            
            [self addObject:item];
            [self setSelectedObjects:[item childPages]];
            
            [self setSelectsInsertedObjects:select];
        }
        else
        {
            [self addObject:item];
        }
    }
    else
    {
        NSBeep();
    }
}

#pragma mark Core Data Support

@synthesize pageTemplate = _template;
- (void)setEntityNameWithPageTemplate:(SVPageTemplate *)pageTemplate;
{
    [self setEntityName:@"Page"];
    [self setPageTemplate:pageTemplate];
}

@synthesize objectURL = _URL;
- (void)setEntityTypeWithURL:(NSURL *)URL external:(BOOL)external;
{
    [self setEntityName:(external ? @"ExternalLink" : @"File")];
    [self setObjectURL:URL];
}

- (void)setEntityName:(NSString *)entityName;
{
    [self setObjectURL:nil];
    [self setPageTemplate:nil];
    
    [super setEntityName:entityName];
}

#pragma mark Managing Objects

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
    
    return [self newObjectWithPredecessor:predecessor followTemplate:YES];
}

- (id)newObjectWithPredecessor:(KTPage *)predecessor followTemplate:(BOOL)allowCollections;
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
        
        
        if (allowCollections)
        {
            SVPageTemplate *template = [self pageTemplate];
        
            
            // Make the page into a collection if it was requested
            if ([[[self pageTemplate] pageProperties] boolForKey:@"isCollection"]) 
            {
                [self configurePageAsCollection:result];
            }
            else
            {
                [result setValuesForKeysWithDictionary:[[self pageTemplate] pageProperties]];
            }
            
            
            // Initial graphic for the page
            if ([template graphicFactory])
            {
                SVGraphic *initialGraphic = [[template graphicFactory] insertNewGraphicInManagedObjectContext:[self managedObjectContext]];
                
                NSAttributedString *graphicHTML = [NSAttributedString attributedHTMLStringWithGraphic:initialGraphic];
                [[initialGraphic textAttachment] setPlacement:[NSNumber numberWithInt:SVGraphicPlacementInline]];
                [initialGraphic awakeFromNew];
                
                SVRichText *article = [result article];
                NSMutableAttributedString *html = [[article attributedHTMLString] mutableCopy];
                [html appendAttributedString:graphicHTML];
                [article setAttributedHTMLString:html];
                [html release];
                
                [initialGraphic didAddToPage:result];
            }
        }
    }
    else if ([[self entityName] isEqualToString:@"ExternalLink"])
    {
        [result setURL:[self objectURL]];
    }
    else if ([[self entityName] isEqualToString:@"File"])
    {
        // Import specified file if possible
        SVMediaRecord *record = nil;
        if ([self objectURL])
        {
            record = [SVMediaRecord mediaByReferencingURL:[self objectURL] entityName:@"FileMedia" insertIntoManagedObjectContext:[self managedObjectContext] error:NULL];
        }
        if (!record)
        {
            NSData *data = [@"" dataUsingEncoding:NSUTF8StringEncoding];
            
            SVMedia *media = [[SVMedia alloc]
                              initWithData:data
                              URL:[NSURL URLWithString:@"x-sandvox-fake-url:///emptystring.html"]];
            
            [media setPreferredFilename:@"Untitled.html"];
            
            record = [SVMediaRecord mediaRecordWithMedia:media
                                              entityName:@"FileMedia"
                          insertIntoManagedObjectContext:[self managedObjectContext]];
            [media release];
        }
        
        [(SVDownloadSiteItem *)result setMedia:record];
    }
    
    return result;
}

- (void)configurePageAsCollection:(KTPage *)collection;
{
    //  Create a collection. Populate according to the index plug-in (-representedObject) if applicable.
    
    
    NSDictionary *presetDict = [[self pageTemplate] pageProperties];
	NSString *identifier = [presetDict objectForKey:@"KTPresetIndexBundleIdentifier"];
	KTElementPlugInWrapper *plugInWrapper = identifier ? [KTElementPlugInWrapper pluginWithIdentifier:identifier] : nil;
	
    NSBundle *indexBundle = [plugInWrapper bundle];
    
    
    // Create the basic collection. collectionMaxSyndicatedPagesCount should have already been set
    [collection setBool:YES forKey:@"isCollection"]; // Duh!
    
    
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
    NSString *firstChildIdentifier = [presetDict valueForKeyPath:@"KTFirstChildSettings.pluginIdentifier"];
    if (firstChildIdentifier && [firstChildIdentifier isKindOfClass:[NSString class]])
    {
        NSMutableDictionary *firstChildProperties =
        [NSMutableDictionary dictionaryWithDictionary:[presetDict objectForKey:@"KTFirstChildSettings"]];
        [firstChildProperties removeObjectForKey:@"pluginIdentifier"];
        
        // Create first child
        KTPage *firstChild = [self newObjectWithPredecessor:collection followTemplate:NO];
        
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
            
            if ([aKey isEqualToString:@"richTextHTML"]) // special case
            {
                [[firstChild article] setString:aProperty attachments:nil];
            }
            else
            {
                [firstChild setValue:aProperty forKeyPath:aKey];
            }
        }
    }
    
    
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
}

#pragma mark Managing Selections

- (BOOL)setSelectedObjects:(NSArray *)objects;
{
    BOOL result = [super setSelectedObjects:objects];
    if (result && [[self selectedObjects] count] < [objects count])
    {
        // SVPagesController loads pages lazily, so selection may not have been loaded yet
        NSDictionary *info = [self infoForBinding:NSContentSetBinding];
        
        NSMutableSet *content = [[info objectForKey:NSObservedObjectKey] mutableSetValueForKeyPath:[info objectForKey:NSObservedKeyPathKey]];
        
        [self saveSelectionAttributes];
        [self setAvoidsEmptySelection:NO];
        [self setPreservesSelection:NO];
        
        [content addObjectsFromArray:objects];
        
        [self restoreSelectionAttributes];
        
        
        // retry
        result = [super setSelectedObjects:objects];
    }
    
    return result;
}

#pragma mark Adding and Removing Objects

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
    
    
    // Suckily, the selection doesn't match the inserted object as it orta. And I can't find a good reason why
    if ([self selectsInsertedObjects] &&
        ![[self selectedObjects] isEqualToArray:[NSArray arrayWithObject:object]])
    {
        [self setSelectedObjects:[NSArray arrayWithObject:object]];
    }
}

- (void)addObjects:(NSArray *)objects toCollection:(KTPage *)collection;
{
    OBPRECONDITION(objects);
    OBPRECONDITION(collection);
    
    
    for (SVSiteItem *anObject in objects)
    {
        [self addObject:anObject toCollection:collection];
    }
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
            [self addObjects:graphics toCollection:collection];
            return YES;
        }
    }
    
    
    BOOL result = NO;
    
    
    // Create graphics for the content
    NSArray *items = [pboard sv_pasteboardItems];
    for (id <SVPasteboardItem> anItem in items)
    {
        SVGraphic *aGraphic = [SVGraphicFactory
                               graphicFromPasteboardItem:anItem
                               minPriority:KTSourcePriorityReasonable   // don't want stuff like list of links
                               insertIntoManagedObjectContext:[self managedObjectContext]];
    
        if (aGraphic)
        {
            // Create pages for each graphic
            [self setEntityName:@"Page"];
            [self setPageTemplate:nil];
            [self setObjectURL:nil];
            
            KTPage *page = [self newObjectDestinedForCollection:collection];
            [page setTitle:[aGraphic title]];
            
            
            // Insert page into the collection. Do before inserting graphic so behaviour dependant on containing collection works. #90905
            [self addObject:page toCollection:collection];
            [page release];
            
            
            // Insert graphic into the page
            //[aGraphic willInsertIntoPage:page];
            
            SVRichText *article = [page article];
            NSMutableAttributedString *html = [[article attributedHTMLString] mutableCopy];
            
            NSAttributedString *attachment = [NSAttributedString
                                              attributedHTMLStringWithGraphic:aGraphic];
            
            [html insertAttributedString:attachment atIndex:0];
            [article setAttributedHTMLString:html];
            [html release];
            
            [aGraphic didAddToPage:page];
        }
        else
        {
            // Fallback to adding download or external URL with location
            NSURL *URL = [anItem URL];
            [self setObjectURL:URL];
            
            if ([URL isFileURL])
            {
                [self setEntityName:@"File"];
                
                SVSiteItem *item = [self newObjectDestinedForCollection:collection];
                [self addObject:item toCollection:collection];
                [item release];
            }
            else
            {
                [self setEntityName:@"ExternalLink"];
                
                SVSiteItem *item = [self newObjectDestinedForCollection:collection];
                
                [self addObject:item toCollection:collection];
                [item release];
            }
        }
        
        result = YES;
    }
    
    return result;
}

- (void)moveObject:(id)object toCollection:(KTPage *)collection index:(NSInteger)index;
{
    [self moveObjects:[NSArray arrayWithObject:object] toCollection:collection index:index];
}

- (void)moveObjects:(NSArray *)objects toCollection:(KTPage *)collection index:(NSInteger)index;
{
    // Add the objects to the collection
    for (SVSiteItem *anItem in objects)
    {
        [anItem retain];    // since we're potentially removing it from relationships etc.
        
        KTPage *parent = [anItem parentPage];
        if (collection != parent)   // no point removing and re-adding a page
        {
            [parent removeChildItem:anItem];
            [collection addChildItem:anItem];
            
            [self didInsertObject:anItem intoCollection:collection];
        }
        
        
        [anItem release];
    }
    
    
    // Then position too if requested. This is done in reverse so we can keep reusing the same index
    if (index != NSOutlineViewDropOnItemIndex)
    {
        for (SVSiteItem *anItem in [objects reverseObjectEnumerator])
        {
            [collection moveChild:anItem toIndex:index];
        }
    }
}

- (void)didInsertObject:(id)object intoCollection:(KTPage *)collection;
{
    // Make sure filename is unique within the collection
    if ([object respondsToSelector:@selector(preferredFilename)])
    {
        NSString *preferredFilename = [object preferredFilename];
        if (![collection isFilenameAvailable:preferredFilename forItem:object])
        {
            [object setFileName:nil];   // needed to fool -suggestedFilename
            NSString *suggestedFilename = [object suggestedFilename];
            [object setFileName:[suggestedFilename stringByDeletingPathExtension]];
        }
    }
}

/* We manage removals by modifying the model directly, so don't call through to super
 */

- (void)removeObjectsAtArrangedObjectIndexes:(NSIndexSet *)indexes
{
    NSArray *objects = [[self arrangedObjects] objectsAtIndexes:indexes];
    
    
    // Should we avoid empty selection after this removal?
    BOOL avoidsEmptySelection = [self avoidsEmptySelection];
    KTPage *nextSelectionParent = nil;
    NSUInteger nextSelectionIndex;

    if (avoidsEmptySelection)
    {
        SVSiteItem *lastSelection = [objects lastObject];
        nextSelectionParent = [lastSelection parentPage];
        nextSelectionIndex = [[nextSelectionParent childPages] indexOfObjectIdenticalTo:lastSelection];
    }
    
                                           
    // Remove the pages from their parents
    [self setAvoidsEmptySelection:NO];
    NSSet *pages = [[NSSet alloc] initWithArray:objects];
    
    NSSet *parentPages = [pages valueForKey:@"parentPage"];
    for (KTPage *aCollection in parentPages)
    {
        [aCollection removePages:pages];	// Far more efficient than calling -removePage: repetitively
    }
    
    [pages release];
    
    
    // Delete
    [self willRemoveObjects:objects];
    
    
    // Setup new selection
    if (nextSelectionParent)
    {
        SVSiteItem *newSelection;
        
        NSArray *children = [nextSelectionParent childPages];
        if ([children count] > nextSelectionIndex)
        {
            newSelection = [children objectAtIndex:nextSelectionIndex];
        }
        else if ([children count] == 0)
        {
            newSelection = nextSelectionParent;
        }
        else
        {
            newSelection = [children lastObject];
        }
        
        [self setSelectedObjects:[NSArray arrayWithObject:newSelection]];
    }
    [self setAvoidsEmptySelection:avoidsEmptySelection];
}

- (void)removeObjectAtArrangedObjectIndex:(NSUInteger)index;
{
    [self removeObjectsAtArrangedObjectIndexes:[NSIndexSet indexSetWithIndex:index]];
}

- (void) willRemoveObject:(id)object;
{
    [super willRemoveObject:object];

    // Delete. Pages have to be treated specially, but I forget quite why
    if ([object isKindOfClass:[KTPage class]])
    {
        [[self managedObjectContext] deletePage:object];
    }
    else
    {
        [[self managedObjectContext] deleteObject:object];
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

