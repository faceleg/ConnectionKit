//
//  KTDocSiteOutlineController.m
//  Marvel
//
//  Created by Terrence Talbot on 1/2/08.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//

#import "SVPagesController.h"

#import "KTPage+Internal.h"
#import "SVExternalLink.h"
#import "SVDownloadSiteItem.h"

#import "SVApplicationController.h"
#import "SVArticle.h"
#import "SVAttributedHTML.h"
#import "KTElementPlugInWrapper.h"
#import "SVMediaGraphic.h"
#import "SVMediaRecord.h"
#import "KTPage+Paths.h"
#import "SVPageTemplate.h"
#import "SVRichText.h"
#import "SVSidebarPageletsController.h"
#import "SVTextAttachment.h"

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

@end


#pragma mark -


@implementation SVPagesController

#pragma mark Creating a Pages Controller

+ (SVPagesController *)controllerWithPagesInCollection:(id <SVPage>)collection;
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
    [_template release];
	[_URL release];
	
    [super dealloc];
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
    NSArray *pagesByDate = [[self arrangedObjects] sortedArrayUsingDescriptors:
                            [KTPage dateCreatedSortDescriptorsAscending:YES]];
    
    KTPage *predecessor = [pagesByDate lastObject];
    
    return [self newObjectWithPredecessor:predecessor followTemplate:YES];
}

- (id)newObjectWithPredecessor:(KTPage *)predecessor followTemplate:(BOOL)followTemplate;
{
    id result = [super newObject];
    
    if ([[self entityName] isEqualToString:@"Page"])
    {
        // Match the basic page properties up to the selection
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

#pragma mark Inserting Objects

- (void)updateContentChildIndexes;
{
    // Get the pages in order. Don't use -arrangedObjects as we want to ignore any filter that's in place
    NSArray *pages = [[self content] sortedArrayUsingDescriptors:[self sortDescriptors]];
    
	NSUInteger i;
	for (i=0; i<[pages count]; i++)
	{
		KTPage *aPage = [pages objectAtIndex:i];
		[aPage setChildIndex:i];
	}
}

- (void)insertObject:(id)object atArrangedObjectIndex:(NSUInteger)index;
{
    // Insert
    [super insertObject:object atArrangedObjectIndex:index];
	
	
	// Attach to master if needed
    KTPage *collection = [(SVSiteItem *)object parentPage];
    if ([object respondsToSelector:@selector(setMaster:)] && [object master] != [collection master])
    {
        [object setMaster:[collection master] recursive:YES];
    }
    
    
    // Attach to site too
    [object setSite:[collection site] recursively:YES];
    
    
    // As it has a new parent, the page's URL must have changed.
    if ([object isKindOfClass:[KTPage class]])
    {
        [object recursivelyInvalidateURL:YES];
    }
    
    
    if ([[collection collectionSortOrder] intValue] == SVCollectionSortManually)
    {
        // Store the ordering in model too
        [self setAutomaticallyRearrangesObjects:NO];
        @try
        {
            [self updateContentChildIndexes];
        }
        @finally
        {
            [self setAutomaticallyRearrangesObjects:YES];
        }
    }
    // Sorted collections trust the insertion to be in correct location
    
    
    // Inherit standard pagelets
    if ([object isKindOfClass:[KTPage class]])
    {
        for (SVGraphic *aPagelet in [[collection sidebar] pagelets])
        {
            [SVSidebarPageletsController addPagelet:aPagelet toSidebarOfPage:object];
        }
    }
    
    
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
    
    
	// Done
    [[NSNotificationCenter defaultCenter] postNotificationName:SVPagesControllerDidInsertObjectNotification object:self];
}

#pragma mark Pasteboard Support

- (SVSiteItem *)newObjectFromPropertyList:(id)aPlist;
{
    [self setEntityName:[aPlist valueForKey:@"entity"]];
    SVSiteItem *result = [self newObject];
    [result awakeFromPropertyList:aPlist parentItem:nil];
    return result;
}

- (void)addObjectFromPasteboardItem:(id <SVPasteboardItem>)anItem
{
    SVGraphic *aGraphic = [SVGraphicFactory
                           graphicFromPasteboardItem:anItem
                           minPriority:SVPasteboardPriorityReasonable   // don't want stuff like list of links
                           insertIntoManagedObjectContext:[self managedObjectContext]];
    
    if (aGraphic)
    {
        // Create pages for each graphic
        [self setEntityNameWithPageTemplate:nil];
        KTPage *page = [self newObject];
        [page setTitle:[aGraphic title]];
        
        
        // First media added to a collection probably doesn't want sidebar. #96013
        if (![[self content] count] && [aGraphic isKindOfClass:[SVMediaGraphic class]])
        {
            [page setShowSidebar:NSBOOL(NO)]; 
        }
        
        
        // Match date of page to media if desired. #102967
        if ([[NSUserDefaults standardUserDefaults] boolForKey:kSVSetDateFromSourceMaterialKey])
        {
            NSURL *URL = [anItem URL];
            if ([URL isFileURL])
            {
                NSDate *date = [[[NSFileManager defaultManager] attributesOfItemAtPath:[URL path]
                                                                                 error:NULL]
                                fileModificationDate];
                
                if (date) [page setCreationDate:date];
            }
        }
        
        
        
        // Insert page into the collection. Do before inserting graphic so behaviour dependant on containing collection works. #90905
        [self addObject:page];
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
        
        SVSiteItem *item = [self newObject];
        [self addObject:item];
        [item release];
    }
    
}

- (BOOL)addObjectsFromPasteboard:(NSPasteboard *)pboard;
{
    if ([[pboard types] containsObject:kKTPagesPboardType])
    {
        NSArray *plists = [pboard propertyListForType:kKTPagesPboardType];
        NSMutableArray *graphics = [NSMutableArray arrayWithCapacity:[plists count]];
        
        for (id aPlist in plists)
        {
            SVSiteItem *item = [self newObjectFromPropertyList:aPlist];
            
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
    
    
    
    
    [self saveSelectionAttributes];
    [self setSelectsInsertedObjects:NO]; // Don't select inserted items. #103298
    @try
    {
        for (id <SVPasteboardItem> anItem in items)
        {
            [self addObjectFromPasteboardItem:anItem];
            result = YES;
        }
    }
    @finally
    {
        [self restoreSelectionAttributes];
    }
    
    
    
    return result;
}

- (id)newObjectFromPasteboardItem:(id <SVPasteboardItem>)pboardItem;
{
    id result = nil;
    
    SVGraphic *aGraphic = [SVGraphicFactory
                           graphicFromPasteboardItem:pboardItem
                           minPriority:SVPasteboardPriorityReasonable   // don't want stuff like list of links
                           insertIntoManagedObjectContext:[self managedObjectContext]];
    
    if (aGraphic)
    {
        // Create pages for each graphic
        [self setEntityNameWithPageTemplate:nil];
        result = [self newObject];
        [result setTitle:[aGraphic title]];
        
        
        // First media added to a collection probably doesn't want sidebar. #96013
        if (![[self content] count] && [aGraphic isKindOfClass:[SVMediaGraphic class]])
        {
            [result setShowSidebar:NSBOOL(NO)]; 
        }
        
        
        // Match date of page to media if desired. #102967
        if ([[NSUserDefaults standardUserDefaults] boolForKey:kSVSetDateFromSourceMaterialKey])
        {
            NSURL *URL = [pboardItem URL];
            if ([URL isFileURL])
            {
                NSDate *date = [[[NSFileManager defaultManager] attributesOfItemAtPath:[URL path]
                                                                                 error:NULL]
                                fileModificationDate];
                
                if (date) [result setCreationDate:date];
            }
        }
        
        
        
        // Insert page into the collection. Do before inserting graphic so behaviour dependant on containing collection works. #90905
        //[self addObject:page toCollection:collection];
        
        
        // Insert graphic into the page
        //[aGraphic willInsertIntoPage:page];
        
        SVRichText *article = [result article];
        NSMutableAttributedString *html = [[article attributedHTMLString] mutableCopy];
        
        NSAttributedString *attachment = [NSAttributedString
                                          attributedHTMLStringWithGraphic:aGraphic];
        
        [html insertAttributedString:attachment atIndex:0];
        [article setAttributedHTMLString:html];
        [html release];
        
        // Inserting the page will call -didAddToPage: on all graphics
    }
    else
    {
        // Fallback to adding download or external URL with location
        NSURL *URL = [pboardItem URL];
        
        BOOL external = ![URL isFileURL];
        [self setEntityTypeWithURL:URL external:external];
        
        result = [self newObject];
        //[self addObject:result toCollection:collection];
    }
    
    return result;
}

#pragma mark KTPageDetailsController compatibility

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

@end



