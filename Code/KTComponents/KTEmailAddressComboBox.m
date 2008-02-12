//
//  KTEmailAddressComboBox.m
//  Marvel
//
//  Created by Terrence Talbot on 12/15/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "KTEmailAddressComboBox.h"

#import <AddressBook/AddressBook.h>
#import "NSString+Karelia.h"
#import "KT.h"
#import "KTAbstractPlugin.h"		// for the benefit of NSLocalizedString macro

#define ANONYMOUS NSLocalizedString(@"Anonymous", "Placeholder")
#define NO_REPLY_ADDRESS @"no_reply@karelia.com"

static NSSet *sAllEmails = nil;
static NSString *sPrimaryEmail = nil;

static BOOL sWillIncludeNames = NO;
static BOOL sWillAddAnonymousEntry = NO;


@interface KTEmailAddressComboBox ( Private )
- (void)populateActiveMailAccounts;
@end


@implementation KTEmailAddressComboBox

#pragma mark class methods

// Returns an unchanging set of all possible email addresses known from various checks.  Might be empty.
+ (NSSet *)allEmailAddresses
{
	if (nil == sAllEmails)
	{
		// Don't have yet, gather
		NSMutableSet *emails = [NSMutableSet set];
		NSString *primaryAddress = nil;
		
		// First look in my address book
		
		ABMultiValue *meAddresses = [[[ABAddressBook sharedAddressBook] me] valueForProperty:kABEmailProperty];
		unsigned int i;
		for (i = 0 ; i < [meAddresses count] ; i++)
		{
			NSString *thisAddress = [meAddresses valueAtIndex:i];
			[emails addObject:thisAddress];
			if (nil == primaryAddress)
			{
				primaryAddress = thisAddress;
			}
		}
		
		// Now get my email addresses from mail.app
		
		NSMutableArray* mailAccounts
			= (NSMutableArray*) CFPreferencesCopyAppValue((CFStringRef) @"MailAccounts", (CFStringRef) @"com.apple.mail");
		[mailAccounts autorelease];
		NSEnumerator *theEnum = [mailAccounts objectEnumerator];
		NSDictionary *accountDict;
		
		while (nil != (accountDict = [theEnum nextObject]) )
		{
			BOOL isActive = YES;
			NSString *isActiveValue = [accountDict objectForKey:@"IsActive"];
			if (nil != isActiveValue)
			{
				isActive = [isActiveValue intValue];
			}
			if (isActive)
			{
				NSArray *emailAddresses = [accountDict objectForKey:@"EmailAddresses"];
				if ([emailAddresses count])
				{
					[emails addObjectsFromArray:emailAddresses];
					if (nil == primaryAddress)
					{
						primaryAddress = [emailAddresses objectAtIndex:0];
					}
				}
			}
		}
		
		NSString *iToolsMember = [[NSUserDefaults standardUserDefaults] objectForKey:@"iToolsMember"];
		if (nil != iToolsMember)
		{
			NSString *iToolsAddr = [NSString stringWithFormat:@"%@@mac.com",iToolsMember];
			[emails addObject:iToolsAddr];
			if (nil == primaryAddress)
			{
				primaryAddress = iToolsAddr;
			}
		}
		
		// Remember these
		sAllEmails = [[NSSet setWithSet:emails] retain];
		sPrimaryEmail = [primaryAddress retain];
	}
	return sAllEmails;
}

// Returns an initial guess of the user's email address.  Might be nil.

+ (NSString *)primaryEmailAddress
{
	if (nil == sAllEmails)
	{
		(void) [self allEmailAddresses];
	}
	return sPrimaryEmail;
}


+ (void) setWillAddAnonymousEntry:(BOOL)anAnonymous
{
	sWillAddAnonymousEntry = anAnonymous;
}

+ (void) setWillIncludeNames:(BOOL)anIncludeNames
{
	sWillIncludeNames = anIncludeNames;
}



#pragma mark dealloc

- (void)dealloc
{
	[myActiveMailAccounts release]; myActiveMailAccounts = nil;
	[myDefaultsAddressKey release]; myDefaultsAddressKey = nil;
	[super dealloc];
}

#pragma mark awake

- (void)awakeFromNib
{
	if (sWillAddAnonymousEntry)
	{
		// add empty item and set placeholder to Optional
		[self addItemWithObjectValue:@""];
		[[self cell] setPlaceholderString:ANONYMOUS];
	}
	
	// add each active Mail account
	[self populateActiveMailAccounts];
	NSEnumerator *e = [myActiveMailAccounts objectEnumerator];
	NSString *email;
	while ( email = [e nextObject] )
	{
		NSString *emailWithName = sWillIncludeNames ? [NSString stringWithFormat:@"%@ (%@)", email, NSFullUserName()] : email;
		[self addItemWithObjectValue:emailWithName];
	}
	
	// select default, or primary, if available
	[self selectItemWithDefaultsKey:[self defaultsAddressKey]];
}

- (void)selectItemWithDefaultsKey:(NSString *)aKey
{
	if (nil != aKey)
	{
		NSString *defaultsAddress = [[NSUserDefaults standardUserDefaults] stringForKey:aKey];
	//	NSString *primaryAddress = [KTEmailAddressComboBox primaryEmailAddress];
		
		if ( nil != defaultsAddress )
		{
			// is it already in the list?
			if ( [self indexOfItemWithObjectValue:defaultsAddress] == NSNotFound )
			{
				// no, assume we want to add it
				[self addItemWithObjectValue:defaultsAddress];
			}
			// select it
			[self selectItemWithObjectValue:defaultsAddress];
		}
	// TJT: commented this out so that we show Anonymous if no default
	//	else if ( [self indexOfItemWithObjectValue:primaryAddress] != NSNotFound )
	//	{
	//		// defaults not found, select primary
	//		[self selectItemAtIndex:[self indexOfItemWithObjectValue:primaryAddress]];
	//	}
		else
		{
			// primary not found, select first email or placeholder
			if ( [self numberOfItems] > 1 )
			{
				[self selectItemAtIndex:1];
			}
			else
			{
				[self selectItemAtIndex:0];
			}
		}
	}
}

- (void)saveSelectionToDefaults
{
	NSString *selection = [self objectValueOfSelectedItem];
	selection = [self stringValue];
	if ( nil != selection && [selection isValidEmailAddress] )
	{
		[[NSUserDefaults standardUserDefaults] setValue:selection forKey:[self defaultsAddressKey]];
	}
}

- (void)populateActiveMailAccounts
{
	[self setActiveMailAccounts:[[KTEmailAddressComboBox allEmailAddresses] allObjects]];
}

- (BOOL)hasActiveMailAccounts
{
	return ([myActiveMailAccounts count] > 0);
}

#pragma mark accessors

- (BOOL)addressIsAnonymous
{
	NSString *selection = [self address];
	
	if ( [selection isEqualToString:NO_REPLY_ADDRESS] )
	{
		return YES;
	}
	else
	{
		return NO;
	}
}

/*!	Returns the string value.  Does not do any validation or converting to anonymous -- client must check about anonymoous.
*/
- (NSString *)address
{
	NSString *selection = [[self stringValue] trimFirstLine];
	return selection;
}

- (NSString *)addressViaDefaults
{
	return [[NSUserDefaults standardUserDefaults] stringForKey:[self defaultsAddressKey]];
}


- (NSArray *)activeMailAccounts
{
    return myActiveMailAccounts; 
}

- (void)setActiveMailAccounts:(NSArray *)anActiveMailAccounts
{
    [anActiveMailAccounts retain];
    [myActiveMailAccounts release];
    myActiveMailAccounts = anActiveMailAccounts;
}

- (NSString *)defaultsAddressKey
{
	return myDefaultsAddressKey;
}

- (void)setDefaultsAddressKey:(NSString *)aKey
{
	[aKey retain];
	[myDefaultsAddressKey release];
	myDefaultsAddressKey = aKey;
	
	// select it
	[self selectItemWithDefaultsKey:myDefaultsAddressKey];
}

@end
