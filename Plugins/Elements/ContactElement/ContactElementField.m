//
//  ContactElementField.m
//  ContactElement
//
//  Created by Mike on 11/05/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "ContactElementField.h"

#import "ContactElementDelegate.h"

#import <NSString-Utilities.h>


@implementation ContactElementField

#pragma mark -
#pragma mark Init & Dealloc

+ (void)initialize
{
	[self setKeys:[NSArray arrayWithObject:@"type"]
		triggerChangeNotificationsForDependentKey:@"tabViewIdentifierForFieldType"];
	
	[self setKeys:[NSArray arrayWithObjects:@"identifier", @"label", nil]
		triggerChangeNotificationsForDependentKey:@"UILabel"];
	
	
}

- (id)initWithIdentifier:(NSString *)identifier
{
	[super init];
	
	myIdentifier = [identifier copy];
	
	return self;
}

- (id)initWithDictionary:(NSDictionary *)dictionary
{
	[self initWithIdentifier:[dictionary objectForKey:@"identifier"]];
	
	[self setType:[[dictionary objectForKey:@"type"] intValue]];
	[self setLabel:[dictionary objectForKey:@"label"]];
	[self setDefaultString:[dictionary objectForKey:@"defaultString"]];
	[self setCheckBoxLabel:[dictionary objectForKey:@"checkBoxLabel"]];
	[self setCheckBoxIsSelected:[[dictionary objectForKey:@"checkBoxIsSelected"] boolValue]];
	[self setVisitorChoices:[dictionary objectForKey:@"visitorChoices"]];
	
	return self;
}

- (void)dealloc
{
	[myIdentifier release];
	[myLabel release];
	[myDefaultString release];
	[myCheckBoxLabel release];
	[myVisitorChoices release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Copy

- (id)copyWithZone:(NSZone *)zone
{
	id copy = [[[self class] allocWithZone:zone] initWithIdentifier:[self identifier]];
	
	[copy setType:[self type]];
	[copy setLabel:[self label]];
	[copy setDefaultString:[self defaultString]];
	[copy setCheckBoxLabel:[self checkBoxLabel]];
	[copy setCheckBoxIsSelected:[self checkBoxIsSelected]];
	[copy setVisitorChoices:[self visitorChoices]];
	
	return copy;
}

#pragma mark -
#pragma mark Owner

- (ContactElementDelegate *)owner { return myOwner; }

- (void)setOwner:(ContactElementDelegate *)owner { myOwner = owner; }

#pragma mark -
#pragma mark Accessors

- (NSString *)identifier { return myIdentifier; }

- (void)setIdentifier:(NSString *)identifier
{
	identifier = [identifier copy];
	[myIdentifier release];
	myIdentifier = identifier;
}

- (ContactElementFieldType)type { return myType; }

- (void)setType:(ContactElementFieldType)type { myType = type; }

- (NSString *)label { return myLabel; }

- (void)setLabel:(NSString *)label
{
	label = [label copy];
	[myLabel release];
	myLabel = label;
}

- (NSString *)labelWithLocalizedColonSuffix;
{
	// LocalizedStringInThisBundle(@":", "used for colons after each label")
	
	NSBundle *bundle = [NSBundle bundleForClass:[self class]];
	NSString *language = [[[self owner] page] valueForKeyPath:@"master.language"];
	NSString *colon = [bundle localizedStringForString:@":" language:language];
	
	NSString *result = [[self label] stringByAppendingString:colon];
	return result;
}

- (NSString *)defaultString { return myDefaultString; }

- (void)setDefaultString:(NSString *)defaultString
{
	defaultString = [defaultString copy];
	[myDefaultString release];
	myDefaultString = defaultString;
}

- (NSString *)checkBoxLabel { return myCheckBoxLabel; }

- (void)setCheckBoxLabel:(NSString *)label
{
	label = [label copy];
	[myCheckBoxLabel release];
	myCheckBoxLabel = label;
}

- (BOOL)checkBoxIsSelected { return myCheckBoxIsSelected; }

- (void)setCheckBoxIsSelected:(BOOL)selected { myCheckBoxIsSelected = selected; }

- (NSArray *)visitorChoices { return myVisitorChoices; }

- (void)setVisitorChoices:(NSArray *)choices
{
	choices = [choices copy];
	[myVisitorChoices release];
	myVisitorChoices = choices;
}

#pragma mark -
#pragma mark UI

/*	A specialised version of -label that is displayed in the Inspector table view.
 */
- (NSString *)UILabel
{
	NSString *result = nil;
	
	NSString *identifier = [self identifier];
	
	if ([@"visitorName" isEqualToString:identifier]) {
		result = LocalizedStringInThisBundle(@"Name", "field label");
	}
	else if ([@"email" isEqualToString:identifier]) {
		result = LocalizedStringInThisBundle(@"Email", @"field label");
	}
	else if ([@"subject" isEqualToString:identifier]) {
		result = LocalizedStringInThisBundle(@"Subject", @"field label");
	}
	else if ([@"message" isEqualToString:identifier]) {
		result = LocalizedStringInThisBundle(@"Message", @"field label");
	}
	else if ([@"send" isEqualToString:identifier]) {
		result = LocalizedStringInThisBundle(@"Send", @"button label");
	}
	else {
		result = [self label];
	}
	
	if (!result || [result isEqualToString:@""]) {
		result = LocalizedStringInThisBundle(@"N/A", @"field label");
	}
	
	return result;
}

- (BOOL)shouldDrawLockIcon
{
	BOOL result = NO;
	
	NSString *identifier = [self identifier];
	if ([identifier isEqualToString:@"visitorName"] ||
		[identifier isEqualToString:@"email"] ||
		[identifier isEqualToString:@"subject"] ||
		[identifier isEqualToString:@"send"] ||
		[identifier isEqualToString:@"message"])
	{
		result = YES;
	}
	
	return result;
}

/*	Which of the tab view items to display in the Inspector for our type
 */
- (NSString *)tabViewIdentifierForFieldType
{
	NSString *result = nil;
	
	switch ([self type])
	{
		case ContactElementTextFieldField:
		case ContactElementTextAreaField:
			result = @"text";
			break;
		
		case ContactElementCheckBoxField:
			result = @"checkbox";
			break;
		
		case ContactElementPopupButtonField:
		case ContactElementRadioButtonsField:
			result = @"multiple";
			break;
		
		case ContactElementHiddenField:
		case ContactElementSubmitButton:	// not really going to be there
			result = @"hidden";
			break;
	}
	
	OBPOSTCONDITION(result);
	return result;
}

#pragma mark -
#pragma mark Storage

/*	Convert all our main accessors to an NSDictionary
 */
- (NSDictionary *)dictionaryRepresentation
{
	NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:5];
	
	[result setValue:[self identifier] forKey:@"identifier"];
	[result setValue:[NSNumber numberWithInt:[self type]] forKey:@"type"];
	[result setValue:[self label] forKey:@"label"];
	[result setValue:[self defaultString] forKey:@"defaultString"];
	[result setValue:[self checkBoxLabel] forKey:@"checkBoxLabel"];
	[result setValue:[NSNumber numberWithBool:[self checkBoxIsSelected]] forKey:@"checkBoxIsSelected"];
	[result setValue:[self visitorChoices] forKey:@"visitorChoices"];
	
	return result;
}

- (id)initWithCoder:(NSCoder *)decoder
{
	[self init];
	
	[self setIdentifier:[decoder decodeObjectForKey:@"identifier"]];
	[self setType:[decoder decodeIntForKey:@"type"]];
	[self setLabel:[decoder decodeObjectForKey:@"label"]];
	[self setDefaultString:[decoder decodeObjectForKey:@"defaultString"]];
	[self setCheckBoxLabel:[decoder decodeObjectForKey:@"checkBoxLabel"]];
	[self setCheckBoxIsSelected:[decoder decodeBoolForKey:@"checkBoxIsSelected"]];
	[self setVisitorChoices:[decoder decodeObjectForKey:@"visitorChoices"]];
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:[self identifier] forKey:@"identifier"];
	[encoder encodeInt:[self type] forKey:@"type"];
	[encoder encodeObject:[self label] forKey:@"label"];
	[encoder encodeObject:[self defaultString] forKey:@"defaultString"];
	[encoder encodeObject:[self checkBoxLabel] forKey:@"checkBoxLabel"];
	[encoder encodeBool:[self checkBoxIsSelected] forKey:@"checkBoxIsSelected"];
	[encoder encodeObject:[self visitorChoices] forKey:@"visitorChoices"];
}

#pragma mark -
#pragma mark HTML

- (NSString *)inputName
{
	NSString *result = nil;
	
	NSString *identifier = [self identifier];
	if ([identifier isEqualToString:@"visitorName"]) {
		result = @"n";
	}
	else if ([identifier isEqualToString:@"email"]) {
		result = @"e";
	}
	else if ([identifier isEqualToString:@"subject"]) {
		result = @"s";
	}
	else if ([identifier isEqualToString:@"message"]) {
		result = @"m";
	}
	else {
		result = [self label];
		
		// If an empty string, replace with "XX"
		if (!result || [result isEqualToString:@""]) {
			result = @"XX";
		}
		
		// If a single character, append an underscore
		if ([result length] == 1) {
			result = [result stringByAppendingString:@"_"];
		}
		
		// Ensure this is not a duplicate by appending a number if necessary
		NSArray *fields = [[self owner] fields];
		unsigned ourIndex = [fields indexOfObjectIdenticalTo:self];
		NSArray *fieldsUpToUs = [fields subarrayWithRange:NSMakeRange(0, ourIndex)];
		NSArray *inputNames = [fieldsUpToUs valueForKeyPath:@"inputName.lowercaseString"];
		
		NSString *possibleName = result;
		int i = 1;
		while ([inputNames containsObject:[possibleName lowercaseString]] ||
			   [possibleName isEqualToStringCaseInsensitive:@"subject"] ||
			   [possibleName isEqualToStringCaseInsensitive:@"message"])
		{
			i++;
			possibleName = [result stringByAppendingFormat:@"%i", i];
		}
		
		result = possibleName;
	}
	
	OBPOSTCONDITION(result);
	
	return result;
}

- (NSString *)description	// used as a tooltip?
{
	return [self inputName];		// well, just provide the same as the input name
}

@end
