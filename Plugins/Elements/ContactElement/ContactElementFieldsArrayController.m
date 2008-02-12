//
//  ContactElementFieldsArrayController.m
//  ContactElement
//
//  Created by Mike on 12/05/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "ContactElementFieldsArrayController.h"
#import "ContactElementField.h"



@implementation ContactElementFieldsArrayController

/*	Returned object should have retain count of 1
 */
//LocalizedStringInThisBundle(@"New field", "The default label for new fields")
- (id)newObject
{
	ContactElementField *newField = [[ContactElementField alloc] initWithIdentifier:@"other"];
	
	[newField setType:ContactElementTextFieldField];
	
	NSBundle *bundle = [NSBundle bundleForClass:[self class]];
	NSString *language = [[pluginDelegate page] valueForKeyPath:@"master.language"];
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

@end
