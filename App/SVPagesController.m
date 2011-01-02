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
#import "SVMediaGraphic.h"
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
#import "KSStringXMLEntityEscaping.h"
#import "KSURLUtilities.h"

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

+ (NSArrayController *)controllerWithPagesInCollection:(id <SVPage>)collection;
{
    NSArrayController *result = [[self alloc] init];
    
    [result bind:NSSortDescriptorsBinding
        toObject:collection
     withKeyPath:@"childItemsSortDescriptors"
         options:nil];
    
    if ([collection isKindOfClass:[NSManagedObject class]])
    {
        // #101711
        [result setEntityName:@"SiteItem"];
        [result setManagedObjectContext:[(NSManagedObject *)collection managedObjectContext]];
    }
    
    [result setAutomaticallyRearrangesObjects:YES];
    
    [result bind:NSContentSetBinding toObject:collection withKeyPath:@"childItems" options:nil];
    
    return [result autorelease];
}

+ (NSArrayController *)controllerWithPagesToIndexInCollection:(id <SVPage>)collection;
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
            [self saveSelectionAttributes];
            [self setSelectsInsertedObjects:NO];
            
            [self addObject:item];
            [self setSelectedObjects:[item childPages]];
            
            [self restoreSelectionAttributes];
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

- (id)newObjectWithPredecessor:(KTPage *)predecessor followTemplate:(BOOL)followTemplate;
{
    id result = [super newObject];
    
    if ([[self entityName] isEqualToString:@"Page"])
    {
        // Match the basic page properties up to the selection
        [result setMaster:[predecessor master]];
        
        if (predecessor)
        {
            [result setShowSidebar:[predecessor showSidebar]];
            [result setAllowComments:[predecessor allowComments]];
            [result setIncludeTimestamp:[predecessor includeTimestamp]];
        }
        
        
        if (followTemplate)
        {
            SVPageTemplate *template = [self pageTemplate];
            [result setMasterIdentifier:[[self pageTemplate] identifier]];
            
            
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
                [initialGraphic setWasCreatedByTemplate:YES];
                
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
			NSString *boilerplateText = NSLocalizedString(@"This can be replaced with any HTML you want.", @"placeholder string");
														  
			NSString *boilerplateFormat = // Minimal, clean, but empty
			@"<!DOCTYPE html>\n<html>\n<head>\n<meta charset='UTF-8' />\n<title></title>\n</head>\n<body>\n\n%@\n\n</body>\n</html>\n";
			NSString *boilerplateHTML = [NSString stringWithFormat:boilerplateFormat, [boilerplateText stringByEscapingHTMLEntities]];
			NSData *data = [boilerplateHTML dataUsingEncoding:NSUTF8StringEncoding];
			
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
    NSString *englishPresetTitle = [presetDict objectForKey:@"SVMasterPageTitle"];
    if (englishPresetTitle)
    {
        NSString *presetTitle = [indexBundle localizedStringForKey:englishPresetTitle value:englishPresetTitle table:nil];
        
        [collection setTitle:presetTitle];
    }
    
    
    // Other settings
    NSDictionary *pageSettings = [presetDict objectForKey:@"SVPageProperties"];
    [collection setValuesForKeysWithDictionary:pageSettings];
    
    
    // Generate a first child page if desired
    NSString *firstChildIdentifier = [presetDict valueForKeyPath:@"SVIndexFirstPageProperties.pluginIdentifier"];
    if (firstChildIdentifier && [firstChildIdentifier isKindOfClass:[NSString class]])
    {
        NSMutableDictionary *firstChildProperties =
        [NSMutableDictionary dictionaryWithDictionary:[presetDict objectForKey:@"SVIndexFirstPageProperties"]];
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

#pragma mark Adding Objects

- (void) insertObject:(id)object atArrangedObjectIndex:(NSUInteger)index;
{
    [super insertObject:object atArrangedObjectIndex:index];
    
    // For some reason, some pages get inserted twice (I think once here, once from content binding) which means there are two copies present in -arrangedObjects. Thus, selecting such an object selects both copis, screwing up the Web Editor. Hacky fix is to rearrange content after each insertion, so the dupe goes away. #101625
    [self rearrangeObjects];
    
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
    
    // Handle folder like its contents. #29203
    if ([items count] == 1)
    {
        id <SVPasteboardItem> item = [items objectAtIndex:0];
        NSURL *URL = [item URL];
        if ([URL isFileURL])
        {
            NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[URL path]
                                                                                    error:NULL];
            
            if (contents)
            {
                NSMutableArray *locations = [NSMutableArray arrayWithCapacity:[contents count]];
                for (NSString *aFilename in contents)
                {
                    NSURL *aURL = [URL ks_URLByAppendingPathComponent:aFilename isDirectory:NO];
                    KSWebLocation *aLocation = [[KSWebLocation alloc] initWithURL:aURL];
                    [locations addObject:aLocation];
                    [aLocation release];
                }
                items = locations;
            }
        }
    }
    
    
    for (id <SVPasteboardItem> anItem in items)
    {
        SVGraphic *aGraphic = [SVGraphicFactory
                               graphicFromPasteboardItem:anItem
                               minPriority:SVPasteboardPriorityReasonable   // don't want stuff like list of links
                               insertIntoManagedObjectContext:[self managedObjectContext]];
    
        if (aGraphic)
        {
            // Create pages for each graphic
            [self setEntityName:@"Page"];
            [self setPageTemplate:nil];
            [self setObjectURL:nil];
            
            KTPage *page = [self newObjectDestinedForCollection:collection];
            [page setTitle:[aGraphic title]];
            
            // First media added to a collection probably doesn't want sidebar. #96013
            if (![[collection childItems] count] && [aGraphic isKindOfClass:[SVMediaGraphic class]])
            {
                [page setShowSidebar:NSBOOL(NO)]; 
            }
                      
            
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
            
            BOOL external = ![URL isFileURL];
            [self setEntityTypeWithURL:URL external:external];
            
            SVSiteItem *item = [self newObjectDestinedForCollection:collection];
            [self addObject:item toCollection:collection];
            [item release];
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

- (void)groupAsCollection:(id)sender;
{
    // New collection
    SVPageTemplate *template = [[SVPageTemplate alloc]
                                initWithCollectionPreset:[NSDictionary dictionary]];
    
    [self setEntityNameWithPageTemplate:template];
    [template release];
    
    KTPage *parent = [[[self selectedObjects] lastObject] parentPage];
    if (!parent)
    {
        // Selection is probably home page!
        NSBeep();
        return;
    }
    
    id collection = [self newObjectDestinedForCollection:parent];
    
    
    // Move selection into it
    [self moveObjects:[self selectedObjects] toCollection:collection index:0];
    
    
    // Fully insert the new, selecting it
    [self addObject:collection toCollection:parent];
    [collection release];
}

#pragma mark Removing Objects

- (void)remove:(id)sender;
{
    [super remove:sender];
    
    // Label undo menu
    NSUndoManager *undoManager = [[self managedObjectContext] undoManager];
    if ([[self selectionIndexes] count] == 1)
    {
        if ([[[self selectedObjects] objectAtIndex:0] isCollection])
        {
            [undoManager setActionName:NSLocalizedString(@"Delete Collection", "Delete Collection MenuItem")];
        }
        else
        {
            [undoManager setActionName:NSLocalizedString(@"Delete Page", "Delete Page MenuItem")];
        }
    }
    else
    {
        [undoManager setActionName:NSLocalizedString(@"Delete Pages", "Delete Pages MenuItem")];
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
    NSUInteger nextSelectionIndex = 0;

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

#pragma mark Convert To Collection

- (NSCellStateValue)selectedItemsAreCollections;
{
    NSNumber *state = [self valueForKeyPath:@"selection.isCollection"];
    NSCellStateValue result = (NSIsControllerMarker(state) ? NSMixedState : [state integerValue]);
    return result;
}

// YES if any of them have
- (BOOL)selectedItemsHaveBeenPublished;
{
    NSDate *published = [self valueForKeyPath:@"selection.datePublished"];
    return (published != nil);
}

- (NSString *)convertToCollectionControlTitle;
{
    NSString *result = ([self selectedItemsAreCollections] ?
                        NSLocalizedString(@"Convert to Single Page", "menu title") :
                        NSLocalizedString(@"Convert to Collection", "menu title"));
    
    if ([self selectedItemsHaveBeenPublished]) result = [result stringByAppendingString:NSLocalizedString(@"…", @"ellipses appended to command, meaning there will be confirmation alert.  Probably spaces before in French.")];
    
    return result;
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

