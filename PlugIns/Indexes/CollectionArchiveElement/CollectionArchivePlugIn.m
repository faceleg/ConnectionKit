//
//  CollectionArchivePlugIn.m
//  CollectionArchiveElement
//
//  Copyright 2006-2010 Karelia Software. All rights reserved.
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

#import "CollectionArchivePlugIn.h"


@implementation CollectionArchivePlugIn

#pragma mark SVIndexPlugIn

// there are no plugIn-specific keys in the template, or elsewhere!




#pragma mark Initialization

- (void)awakeFromNew;
{
    //FIXME: verify that superclass attempts to connect indexedCollection to our page's parent
    [super awakeFromNew];
    
    if ( self.indexedCollection )
    {
        // attempt to set container's title to localized string
        NSString *title = [NSString stringWithFormat:@"%@ %@",
                           [self.indexedCollection title],
                           LocalizedStringInThisBundle(@"Archive", @"Portion of pagelet title")];
        self.container.title = title;
    }
    
    // tell our collection we want to generate archives
    [self.indexedCollection setCollectionGenerateArchives:YES];
}



#pragma mark Properties

/*	Changing collection means disabling archives on the old collection if necessary
 */


//- (void)plugin:(id)plugin didSetValue:(id)value forPluginKey:(NSString *)key oldValue:(id)oldValue
//{
//	if ([key isEqualToString:@"collection"])
//	{
//		// Turn off the old collection's archives if not needed
//		BOOL enableArchives = NO;
//		NSArray *archivePagelets = [[plugin managedObjectContext] pageletsWithPluginIdentifier:[[self bundle] bundleIdentifier]];
//		NSEnumerator *pageletsEnumerator = [archivePagelets objectEnumerator];
//		id aPagelet;    // was KTPagelet
//		while (aPagelet = [pageletsEnumerator nextObject])
//		{
//			if ([[aPagelet valueForKey:@"collection"] isEqual:(KTPage *)oldValue])
//			{
//				enableArchives = YES;
//				break;
//			}
//		}
//		[(KTPage *)oldValue setCollectionGenerateArchives:enableArchives];
//		
//		// Enable archives on the new page.
//		[(KTPage *)value setCollectionGenerateArchives:YES];
//	}
//}


- (void)setIndexedCollection:(id <SVPage>)collection
{
    // when we change indexedCollection, turn off generateArchives on old indexedCollection
    // if no other CollectionArchive pagelets are attached to it, turn it on for new indexedCollection
    
    //FIXME: how do we implement testing all other plugins being attached to oldCollection?
    // see S1 code commented out, above, for old way of doing it
    id <SVPage> oldCollection = [self indexedCollection];
    
    
    [super setIndexedCollection:collection];
    
    // Enable archives on the new page.
    //[collection setCollectionGenerateArchives:YES];
}

@end
