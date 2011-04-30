//
//  ContactElementField.m
//  ContactElement
//
//  Copyright 2007-2011 Karelia Software. All rights reserved.
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
//  Community Note: This code is distributed under a modified BSD License.
//  We encourage you to share your Sandvox Plugins similarly.
//

#import "ContactElementField.h"

#import "ContactPlugIn.h"

@interface ContactElementField ()
- (void)setIdentifier:(NSString *)string;
@end

@implementation ContactElementField


#pragma mark Init & Dealloc

- (id)initWithIdentifier:(NSString *)identifier
{
	[super init];
    
    self.identifier = identifier;
	
	
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
    self.identifier = nil;
    self.label = nil;
    self.defaultString = nil;
    self.checkBoxLabel = nil;
    self.visitorChoices = nil;	
	[super dealloc];
}


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


#pragma mark UI

+ (NSSet *)keyPathsForValuesAffectingUILabel
{
    return [NSSet setWithObjects:@"identifier", @"label", nil];
}

/*	A specialised version of -label that is displayed in the Inspector table view.
 */
- (NSString *)UILabel
{
	NSString *result = nil;
	
	NSString *identifier = [self identifier];
	
	if ([@"visitorName" isEqualToString:identifier]) 
    {
		result = SVLocalizedString(@"Name", "field label");
	}
	else if ([@"email" isEqualToString:identifier]) 
    {
		result = SVLocalizedString(@"Email", @"field label");
	}
	else if ([@"subject" isEqualToString:identifier]) 
    {
		result = SVLocalizedString(@"Subject", @"field label");
	}
	else if ([@"message" isEqualToString:identifier]) 
    {
		result = SVLocalizedString(@"Message", @"field label");
	}
	else if ([@"send" isEqualToString:identifier]) 
    {
		result = SVLocalizedString(@"Send", @"button label");
	}
	else 
    {
		result = [self label];
	}
	
	if (!result || [result isEqualToString:@""]) 
    {
		result = SVLocalizedString(@"N/A", @"field label");
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

+ (NSSet *)keyPathsForValuesAffectingTabViewIdentifierForFieldType
{
    return [NSSet setWithObject:@"type"];
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
		case ContactElementSubmitButton:	// the "Default value" field will be hidden
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
			result = @"hidden";
			break;
	}
	
	NSAssert((nil != result), @"result may not be nil");
	return result;
}

- (BOOL)hideValueField
{
	BOOL result = NO;
	if ([self type] == ContactElementSubmitButton)
	{
		result = YES;
	}
	
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

/*  For custom fields, generates an HTML input name based on the label, but does NOT unique it in any way
 */
- (NSString *)preferredInputName
{
    NSString *result = [self label];
    
    // If an empty string, replace with "XX"
    if (!result || [result isEqualToString:@""]) {
        result = @"XX";
    }
    
    // If a single character, append an underscore
    if ([result length] == 1) {
        result = [result stringByAppendingString:@"_"];
    }
    
    return result;
}

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
		NSString *preferredName = result = [self preferredInputName];
		
		// Ensure this is not a duplicate by appending a number if necessary
		NSArray *fields = [[self owner] fields];
        unsigned ourIndex = [fields indexOfObjectIdenticalTo:self];
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"preferredInputName LIKE[c] %@", result];
		NSArray *previousMatches = [[fields subarrayWithRange:NSMakeRange(0, ourIndex)] filteredArrayUsingPredicate:predicate];
		
		int i = [previousMatches count];
		while ([previousMatches count] > 0)
		{
			i ++;
			result = [preferredName stringByAppendingFormat:@"%i", i];
            
            predicate = [NSPredicate predicateWithFormat:@"preferredInputName LIKE[c] %@", result];
            previousMatches = [[fields subarrayWithRange:NSMakeRange(0, ourIndex)] filteredArrayUsingPredicate:predicate];
		}
    }
	
	NSAssert((nil != result), @"result may not be nil");
	return result;
}

- (NSString *)description	// used as a tooltip?
{
	return [self inputName];		// well, just provide the same as the input name
}


#pragma mark Properties

@synthesize owner = _owner;
@synthesize identifier = _identifier;
- (void)setIdentifier:(NSString *)string
{
    NSString *copy = [string copy];
    [_identifier release];
    _identifier = copy;
}
@synthesize type = _type;
@synthesize label = _label;
@synthesize defaultString = _defaultString;
@synthesize checkBoxLabel = _checkBoxLabel;
@synthesize checkBoxIsSelected = _checkBoxIsSelected;
@synthesize visitorChoices = _visitorChoices;

@end
