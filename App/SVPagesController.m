//
//  KTDocSiteOutlineController.m
//  Marvel
//
//  Created by Terrence Talbot on 1/2/08.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "SVPagesController.h"

#import "KTElementPlugin.h"
#import "KTAbstractIndex.h"
#import "KTIndexPlugin.h"
#import "KTPage+Internal.h"
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


#pragma mark -


@implementation SVPagesController

#pragma mark Managing Objects

- (IBAction)addCollection:(id)sender;
{
    //  Create a collection. Populate according to the index plug-in (-representedObject) if applicable.
    
    
    NSDictionary *presetDict = [sender representedObject];
	NSString *identifier = [presetDict objectForKey:@"KTPresetIndexBundleIdentifier"];
	KTIndexPlugin *indexPlugin = identifier ? [KTIndexPlugin pluginWithIdentifier:identifier] : nil;
	
    NSBundle *indexBundle = [indexPlugin bundle];
    
    
    // Create the basic collection
    KTPage *collection = [self newObject];
    [collection setBool:YES forKey:@"isCollection"]; // Duh!
    
    
    // Set the index on the page
    [collection setWrappedValue:identifier forKey:@"collectionIndexBundleIdentifier"];
    Class indexToAllocate = [indexBundle principalClassIncludingOtherLoadedBundles:YES];
    KTAbstractIndex *theIndex = [[((KTAbstractIndex *)[indexToAllocate alloc]) initWithPage:collection plugin:indexPlugin] autorelease];
    [collection setIndex:theIndex];
    
    
    // Now re-set title of page to be the appropriate untitled name
    NSString *englishPresetTitle = [presetDict objectForKey:@"KTPresetUntitled"];
    NSString *presetTitle = [indexBundle localizedStringForKey:englishPresetTitle value:englishPresetTitle table:nil];
    
    [collection setTitleWithString:presetTitle];
    
    NSDictionary *pageSettings = [presetDict objectForKey:@"KTPageSettings"];
    [collection setValuesForKeysWithDictionary:pageSettings];
        
    
    // Insert the new collection
    [self addObject:collection];
    [collection release];
    
    
    // Generate a first child page if desired
    NSString *firstChildIdentifier = [presetDict valueForKeyPath:@"KTFirstChildSettings.pluginIdentifier"];
    if (firstChildIdentifier && [firstChildIdentifier isKindOfClass:[NSString class]])
    {
        NSMutableDictionary *firstChildProperties =
        [NSMutableDictionary dictionaryWithDictionary:[presetDict objectForKey:@"KTFirstChildSettings"]];
        [firstChildProperties removeObjectForKey:@"pluginIdentifier"];
        
        // Create first child
        KTPage *firstChild = [self newObject];
        
        // Insert at right place. DON'T want this one to be selected
        BOOL insertSelected = [self selectsInsertedObjects];
        [self setSelectsInsertedObjects:NO];
        [self addPage:firstChild asChildOfPage:collection];
        [self setSelectsInsertedObjects:insertSelected];
        
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
                [[[[firstChild body] orderedElements] lastObject] setArchiveString:aProperty];
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
            
            [[[[collection body] orderedElements] lastObject] setArchiveString:intro];
        }
    }
}

- (void)addObject:(KTPage *)page
{
    // Figure out where to insert the page. i.e. from our selection, what collection should it be made a child of?
    KTPage *parent = [[self selectedObjects] lastObject];
    if (![parent isCollection]) parent = [parent parentPage];
    if (!parent) parent = [[self managedObjectContext] root];
    
    
    [self addPage:page asChildOfPage:parent];
}

- (void)addPage:(KTPage *)page asChildOfPage:(KTPage *)parent;
{
    OBPRECONDITION(page);
    OBPRECONDITION(parent);
    
    
    // Figure out the predecessor (which page to inherit properties from)
    KTPage *predecessor = parent;
	NSArray *children = [parent childrenWithSorting:KTCollectionSortLatestAtTop inIndex:NO];
	if ([children count] > 0)
	{
		predecessor = [children firstObjectKS];
	}
	
	
    // Attach to parent & other relationships
	[page setMaster:[parent master]];
	[page setSite:[parent valueForKeyPath:@"site"]];
	[parent addPage:page];	// Must use this method to correctly maintain ordering
	
	
    // Load properties from parent/sibling
	[page setAllowComments:[predecessor allowComments]];
	[page setIncludeTimestamp:[predecessor includeTimestamp]];
	
	
	// Keeping it old school. Let the page know it's being inserted
    [page awakeFromBundleAsNewlyCreatedObject:YES];
    
    
    // Give it standard pagelets
    [[page sidebar] addPagelets:[[parent sidebar] pagelets]];
    
    
    // Finally, do the actual controller-level insertion
    [super addObject:page];
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

