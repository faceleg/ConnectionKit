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

#import "KTElementPlugInWrapper.h"
#import "KTAbstractIndex.h"
#import "KTIndexPlugInWrapper.h"
#import "SVLink.h"
#import "SVLinkManager.h"
#import "SVMediaRecord.h"
#import "SVRichText.h"
#import "SVSidebar.h"

#import "NSArray+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSObject+Karelia.h"

#import "Debug.h"


/*	These strings are localizations for case https://karelia.fogbugz.com/default.asp?4736
 *	Not sure when we're going to have time to implement it, so strings are placed here to ensure they are localized.
 *
 *	NSLocalizedString(@"There is already a page with the file name \\U201C%@.\\U201D Do you wish to rename it to \\U201C%@?\\U201D",
					  "Alert message when changing the file name or extension of a page to match an existing file");
 *	NSLocalizedString(@"There are already some pages with the same file name as those you are adding. Do you wish to rename them to be different?",
					  "Alert message when pasting/dropping in pages whose filenames conflict");
 */


@interface SVPagesController ()
- (id)newObjectAllowingCollections:(BOOL)allowCollections;
- (void)configurePageAsCollection:(KTPage *)collection;
@end


#pragma mark -


@implementation SVPagesController

#pragma mark Managing Objects

@dynamic entityName;

@synthesize collectionPreset = _presetDict;
@synthesize fileURL = _fileURL;

- (id)newObject
{
    return [self newObjectAllowingCollections:YES];
}

- (id)newObjectAllowingCollections:(BOOL)allowCollections
{
    id result = [super newObject];
    
    if ([[self entityName] isEqualToString:@"Page"])
    {
        // Figure out the predecessor (which page to inherit properties from)
        KTPage *parent = [[self selectedObjects] lastObject];
        if (![parent isCollection]) parent = [parent parentPage];
        OBASSERT(parent);
    
        KTPage *predecessor = parent;
        NSArray *children = [parent childrenWithSorting:SVCollectionSortByDateCreated
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
        
        
        // Match the basic page properties up to the selection
        [result setMaster:[parent master]];
        
        [result setAllowComments:[predecessor allowComments]];
        [result setIncludeTimestamp:[predecessor includeTimestamp]];
        
        
        // Give it standard pagelets
        [[result sidebar] addPagelets:[[parent sidebar] pagelets]];
        
        
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
            
            media = [SVMediaRecord mediaWithFileContents:data
                                             URLResponse:nil
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
	KTIndexPlugInWrapper *indexPlugin = identifier ? [KTIndexPlugInWrapper pluginWithIdentifier:identifier] : nil;
	
    NSBundle *indexBundle = [indexPlugin bundle];
    
    
    // Create the basic collection
    [collection setBool:YES forKey:@"isCollection"]; // Duh!
    
    
    // Set the index on the page
    [collection setWrappedValue:identifier forKey:@"collectionIndexBundleIdentifier"];
    Class indexToAllocate = [indexBundle principalClassIncludingOtherLoadedBundles:YES];
    KTAbstractIndex *theIndex = [[((KTAbstractIndex *)[indexToAllocate alloc]) initWithPage:collection plugin:indexPlugin] autorelease];
    [collection setIndex:theIndex];
    
    
    // Now re-set title of page to be the appropriate untitled name
    NSString *englishPresetTitle = [presetDict objectForKey:@"KTPresetUntitled"];
    NSString *presetTitle = [indexBundle localizedStringForKey:englishPresetTitle value:englishPresetTitle table:nil];
    
    [collection setTitle:presetTitle];
    
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
                [[firstChild body] setString:aProperty attachments:nil];
            }
            else
            {
                [firstChild setValue:aProperty forKeyPath:aKey];
            }
        }
    }
    
    
    // Any collection with an RSS feed should have an RSS Badge.
    if ([pageSettings boolForKey:@"collectionSyndicate"])
    {
        // Give weblogs special introductory text
        if ([[presetDict objectForKey:@"KTPresetIndexBundleIdentifier"] isEqualToString:@"sandvox.GeneralIndex"])
        {
            NSString *intro = NSLocalizedString(@"This is a new weblog. You can replace this text with an introduction to your blog, or just delete it if you wish. To add an entry to the weblog, add a new page using the \\U201CPages\\U201D button in the toolbar. For more information on blogging with Sandvox, please have a look through our <a href=\"help:Blogging_with_Sandvox\">help guide</a>.",
                                                "Introductory text for Weblogs");
            
            [[collection body] setString:intro attachments:nil];
        }
    }
}

- (void)addObject:(KTPage *)page
{
    // Figure out where to insert the page. i.e. from our selection, what collection should it be made a child of?
    KTPage *parent = [[self selectedObjects] lastObject];
    if (![parent isCollection]) parent = [parent parentPage];
    OBASSERT(parent);
    
    
    [self addObject:page asChildOfPage:parent];
}

- (void)addObject:(id)object asChildOfPage:(KTPage *)parent;
{
    OBPRECONDITION(object);
    OBPRECONDITION(parent);
    
    
    // Attach to parent & other relationships
    [object setSite:[parent site] recursively:YES];
    [parent addChildItem:object];	// Must use this method to correctly maintain ordering
	
	
    // Do the actual controller-level insertion
    [super addObject:object];
    
    
    // Include in site menu if appropriate
    if ([parent isRootPage] && [[parent childItems] count] < 7)
    {
        [object setIncludeInSiteMenu:YES];
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

@end

