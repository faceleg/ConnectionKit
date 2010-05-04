//
//  LinkListArrayController.m
//  Sandvox SDK
//
//  Copyright 2005-2009 Karelia Software. All rights reserved.
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

#import "LinkListArrayController.h"


@implementation LinkListArrayController

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    [tableView setDataSource:self];
    [tableView setDelegate:self];
}

/*!	Create a new "template" object.  Try to pick up default from frontmost Safari doc.
*/
- (id)newObject	// must return object with a retain count of one
{
	NSString *theURLString = @"http://";
	NSString *theTitle = LocalizedStringInThisBundle(@"Name",@"Initial title of an item in a list of web links");
	NSURL *theURL = nil;
	[NSAppleScript getWebBrowserURL:&theURL title:&theTitle source:nil];
	if (theURL)	theURLString = [theURL absoluteString];
	
	NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
		[theTitle stringByEscapingHTMLEntities], @"titleHTML",
		theURLString, @"url",
		nil];
	return result;
}

/*!	Also accept drag URL drag.  
*/
- (NSArray *)urlTypes { return SVWebLocationGetReadablePasteboardTypes(nil); }

- (NSArray *)dragTypesToRegister
{
	return [[super dragTypesToRegister] arrayByAddingObjectsFromArray:[self urlTypes]];
}

- (BOOL)tableView:(NSTableView*)tv
	   acceptDrop:(id <NSDraggingInfo>)info
			  row:(int)row
	dropOperation:(NSTableViewDropOperation)op
{
    BOOL didInsert = NO;
	
	if (row < 0) {	// Handle inserting at the very top of the list
		row = 0;
	}
    
	
	// Let our superclass try before we get a crack at it
	if ([super tableView:tv acceptDrop:info row:row dropOperation:op]) {
		return YES;	// super handled it
	}
	
	
	// Get the URLs and titles from the pasteboard
	NSPasteboard *pasteboard = [info draggingPasteboard];
	
	NSArray *webLocations = [NSClassFromString(@"KSWebLocation") webLocationsFromPasteboard:pasteboard readWeblocFiles:YES ignoreFileURLs:YES];
	
	
	
	// Run through the URLs, adding them to the table
	unsigned int i;
	for (i = 0; i < [webLocations count]; i++)
	{
		id <SVWebLocation> aWebLocation = [webLocations objectAtIndex:i];
		
		// If passed NSNull as a title it means none could be found. We want to use the hostname in such cases
		NSString *title = [aWebLocation title];
		if (!title) title = [[aWebLocation URL] host];
		
		
		NSMutableDictionary *newObject = [NSMutableDictionary dictionaryWithObjectsAndKeys:
			[[aWebLocation URL] absoluteString], @"url",
			[title stringByEscapingHTMLEntities], @"titleHTML",
			nil];
		
		[self insertObject:newObject atArrangedObjectIndex:row];
		[self setSelectionIndex:row];	// set selection to those that were just copied
		
		row++;
		didInsert = YES;
	}
	
	return (didInsert);		// only return YES if we actually inserted something
}

@end
