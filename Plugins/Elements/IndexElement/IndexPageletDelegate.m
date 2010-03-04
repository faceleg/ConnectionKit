//
//  IndexPageletDelegate.m
//  IndexPagelet
//
//  Copyright 2006-2009 Karelia Software. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  *  Redistribution of source code must retain the above copyright notice,
//     this list of conditions and the follow disclaimer.
//
//  *  Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other material provided with the distribution.
//
//  *  Neither the name of Karelia Software nor the names of its contributors
//     may be used to endorse or promote products derived from this software
//     without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS-IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUR OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//
//  Community Note: This code is distrubuted under a modified BSD License.
//  We encourage you to share your Sandvox Plugins similarly.
//

#import "IndexPageletDelegate.h"

// LocalizedStringInThisBundle(@"Please specify the collection to index using the Pagelet Inspector.", "String_On_Page_Template")



@implementation IndexPageletDelegate

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key
{
	if ([key isEqualToString:@"indexedPage"])
	{
		return NO;
	}
	else
	{
		return [super automaticallyNotifiesObserversForKey:key];
	}
}

#pragma mark -
#pragma mark Init & Dealloc

- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewlyCreated
{
	// We want to know when changes are made to the context so that we know if our collection has been deleted
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(indexedPageMayHaveBeenDeleted:)
												 name:NSManagedObjectContextObjectsDidChangeNotification
											   object:[[self delegateOwner] managedObjectContext]];
    
    // 1.5 plugins won't have a maxSummaryCharacters value. We need to provide one
    if (!isNewlyCreated)
    {
        if (![[self delegateOwner] valueForKey:@"enableMaxItems"])
        {
            [[self delegateOwner] setBool:YES forKey:@"enableMaxItems"];
        }
        
        if (![[self delegateOwner] valueForKey:@"maxSummaryCharacters"])
        {
            [[self delegateOwner] setInteger:1000 forKey:@"maxSummaryCharacters"];
        }
    }
}

- (void)awakeFromNib
{
	[oLinkView setConnected:(nil != [[self delegateOwner] valueForKey:@"indexedPage"])];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self
												    name:NSManagedObjectContextObjectsDidChangeNotification
												  object:[[self delegateOwner] managedObjectContext]];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Index details

// When changing the collection, change pagelet title HTML to match
- (void)plugin:(id)plugin didSetValue:(id)value forPluginKey:(NSString *)key oldValue:(id)oldValue;
{
	if ([key isEqualToString:@"indexedPage"] && [value isKindOfClass:[KTPage class]])   // Sanity check for imports
	{
		if (!value)
		{
			[[self delegateOwner] setTitleHTML:[[self bundle] objectForInfoDictionaryKey:@"KTPluginUntitledName"]];
		}
		else
		{
			[[self delegateOwner] setTitleHTML:[value titleText]];
		}
	}
}

/*	If our collection is deleted, set indexedPage to nil
 */
- (void)indexedPageMayHaveBeenDeleted:(NSNotification *)notification
{
	NSSet *deletedObjects = [[notification userInfo] objectForKey:NSDeletedObjectsKey];
	if ([deletedObjects containsObject:[[self delegateOwner] valueForKey:@"indexedPage"]])
	{
		[[self delegateOwner] setValue:nil forKey:@"indexedPage"];
	}
}

#pragma mark -
#pragma mark HTML

/*  Supplements the -maxItems property stored in our element by returning 0 if the user has disabled the maximum
 */
- (unsigned)maxItems
{
    unsigned result = 0;
    
    if ([[self delegateOwner] boolForKey:@"enableMaxItems"])
    {
        result = [[self delegateOwner] integerForKey:@"maxItems"];
    }
    
    return result;
}

#pragma mark -
#pragma mark Link Source Delegate

- (IBAction)clear:(id)sender
{
	[[self delegateOwner] setValue:nil forKey:@"indexedPage"];
}

// This is supposed to return a document so that the connector knows to connect only to its document's site outline object


- (id)userInfoForLinkSource:(KTLinkSourceView *)link
{
	return [[self page] site];
}

- (NSPasteboard *)linkSourceDidBeginDrag:(KTLinkSourceView *)link
{
	NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
	[pboard declareTypes:[NSArray arrayWithObject:@"kKTLocalLinkPboardType"] owner:self];
	[pboard setString:@"KTCollection" forType:@"kKTLocalLinkPboardType"];	// signify we want collections only
	
	return pboard;
}

- (void)linkSourceDidEndDrag:(KTLinkSourceView *)link withPasteboard:(NSPasteboard *)pboard
{
	NSString *pageID = [pboard stringForType:@"kKTLocalLinkPboardType"];
	if ( (pageID != nil) && ![pageID isEqualToString:@""]  && ![pageID isEqualToString:@"KTCollection"] )
	{
		KTPage *target = [KTPage pageWithUniqueID:pageID inManagedObjectContext:[[self delegateOwner] managedObjectContext]];
		if ( nil != target )
		{
			[[self delegateOwner] setValue:target forKey:@"indexedPage"];
		}
	}
}

@end

#pragma mark -
#pragma mark Data Migrator

@interface NSObject (IndexPageletDataMigrator)
- (id)initWithClassName:(NSString *)className entityName:(NSString *)entityName ID:(NSString *)ID;
@end


@implementation IndexPageletDelegate (DataMigration)

/*  We need to manually import collection IDs to the new format. This is a little hacky using (Sandvox's) private API
 */
- (BOOL)importPluginProperties:(NSDictionary *)oldPluginProperties
                    fromPlugin:(NSManagedObject *)oldPlugin
                         error:(NSError **)error
{
    [[self delegateOwner] setValuesForKeysWithDictionary:oldPluginProperties];
    
    
    NSString *collectionID = [oldPluginProperties objectForKey:@"collectionID"];
    id archivedObject = nil;
    if (collectionID)
    {
        Class archiveClass = NSClassFromString(@"KTExtensiblePluginPropertiesArchivedObject");
        archivedObject = [[archiveClass alloc] initWithClassName:@"KTPage" entityName:@"Page" ID:collectionID];
    }
    
    [[self delegateOwner] setValue:archivedObject forKey:@"indexedPage"];
    [archivedObject release];
         
    
    if (error) *error = nil;
    return YES;
}

@end
