//
//  KTPlaceholderBindingTextField.m
//  Marvel
//
//  Created by Mike on 05/02/2008.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//

#import "KTPlaceholderBindingTextField.h"


@implementation KTPlaceholderBindingTextField

+ (void)initialize
{
	[self exposeBinding:@"placeholderValue"];
}

- (void)dealloc
{
	[myPlaceholder release];
	[super dealloc];
}

/*	So these 2 manage the binding very simply
 */
- (NSString *)placeholderValue { return myPlaceholder; }

- (NSString *)placeholderStringForCell
{
	NSString *result = [self placeholderValue];
	if (!result) result = @"";
	return result;
}

- (void)setPlaceholderValue:(NSString *)placeholder
{
	placeholder = [placeholder copy];
	[myPlaceholder release];
	myPlaceholder = placeholder;
	
	[[self cell] setPlaceholderString:[self placeholderStringForCell]];
}

/*	To stop the default bindings messing things up, we must reset the cell's
 *	placeholder string when the user ends editing.
 */
- (void)textDidEndEditing:(NSNotification *)aNotification
{
	[super textDidEndEditing:aNotification];
	
	[[self cell] setPlaceholderString:[self placeholderStringForCell]];
}

@end
