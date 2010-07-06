//
//  ContactElementFieldsArrayController.m
//  ContactElement
//
//  Copyright 2007-2009 Karelia Software. All rights reserved.
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

#import "ContactElementFieldsArrayController.h"
#import "ContactElementField.h"
#import "ContactElementFieldCell.h"


@implementation ContactElementFieldsArrayController

/*	Returned object should have retain count of 1
 */
//LocalizedStringInThisBundle(@"New field", "The default label for new fields")
- (id)newObject
{
	ContactElementField *newField = [[ContactElementField alloc] initWithIdentifier:@"other"];
	
	[newField setType:ContactElementTextFieldField];
	
	NSBundle *bundle = [NSBundle bundleForClass:[self class]];
	NSString *language = [[[SVPageletPlugIn currentContext] page] language];
	[newField setLabel:[bundle localizedStringForString:@"New field" language:language]];
	
	return newField;
}

/*	Ensure newly inserted objects are selected.
 */
- (void)insertObject:(id)object atArrangedObjectIndex:(unsigned int)index
{
	[super insertObject:object atArrangedObjectIndex:index];
	[self setSelectionIndex:index];
}	

/*	When the user adds a new field:
 *	If the Message field is the last in the list, add this new field just before it
 */
- (void)add:(id)sender
{
	NSArray *fields = [self arrangedObjects];
	if ([[[fields lastObject] identifier] isEqualToString:@"send"])
	{
		int subtract = 1;
		if ([[[fields objectAtIndex:[fields count]-2] identifier] isEqualToString:@"message"])
		{
			subtract++;
		}
		ContactElementField *newField = [self newObject];
		[self insertObject:newField atArrangedObjectIndex:([fields count] - subtract)];
		[newField release];
	}
	else
	{
		[super add:sender];
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:@"AddedMessageField" object:self];
}

/*	If removing the last object in the array, select the new last object
 */	
- (void)removeObjectAtArrangedObjectIndex:(unsigned int)index
{
	[super removeObjectAtArrangedObjectIndex:index];
	
	unsigned count = [[self arrangedObjects] count];
	if (index >= count) {
		[self setSelectionIndex:(count - 1)];
	}
}

#pragma mark -
#pragma mark Drawing

/*	Set the -locked property of cells before they draw
 */
- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	if (![aCell isKindOfClass:[ContactElementFieldCell class]]) return;
	
	ContactElementField *field = [[self arrangedObjects] objectAtIndex:rowIndex];
	[aCell setLocked:[field shouldDrawLockIcon]];
}

@end
