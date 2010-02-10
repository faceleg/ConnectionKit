//
//  ContactElementDelegate.m
//  ContactElement
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

#import "ContactElementDelegate.h"
#import "ContactElementInspectorController.h"
#import "ContactElementField.h"

#import "SandvoxPlugin.h"
// defines CONTACT_PASSWORD, not supplied
#import <ContactPassword.h>

#include <openssl/blowfish.h>
#include <zlib.h>

// LocalizedStringInThisBundle(@"Please specify an address for the recipient using the Inspector.", "String_On_Page_Template")
// LocalizedStringInThisBundle(@"Email address is missing.  Message cannot be sent.", "String_On_Page_Template")
// LocalizedStringInThisBundle(@"No message has been entered.  Message cannot be sent.", "String_On_Page_Template")
// LocalizedStringInThisBundle(@"Please leave this field empty:", "Title of invisible, anti-spam field")
// LocalizedStringInThisBundle(@"Submitting Form...", "String_On_Page_Template")
// LocalizedStringInThisBundle(@"Unable to Submit form. Result code = ", "String_On_Page_Template.  Followed by a number.")
// LocalizedStringInThisBundle(@"Message sent.", "String_On_Page_Template ")

enum { LABEL_NAME = 1, LABEL_EMAIL, LABEL_SUBJECT, LABEL_MESSAGE, LABEL_SEND };

@interface ContactElementDelegate ()

- (void)setFields:(NSArray *)fields archiveToPluginProperties:(BOOL)archive;
- (NSArray *)fieldsPropertyListRepresentation;
- (NSArray *)fieldsByFetchingFromPluginProperties;

#ifdef DEBUG
- (void)decode:(NSString *)v;
#endif
@end


@implementation ContactElementDelegate

/*
 Plugin Properties we use:
	
 sendButtonTitle
 subjectPrompt
 subjectText
 subjectType
 address
 
 */

enum { kKTContactSubjectHidden, kKTContactSubjectField, kKTContactSubjectSelection };

#pragma mark -
#pragma mark Init & Dealloc

+ (void) initialize
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	

    [ContactElementDelegate setKeys:
        [NSArray arrayWithObjects: @"address", nil]
        triggerChangeNotificationsForDependentKey: @"encodedRecipient"];
	[ContactElementDelegate setKeys:
        [NSArray arrayWithObjects: @"subjectType", nil]
        triggerChangeNotificationsForDependentKey: @"subjectPrompt"];
	[ContactElementDelegate setKeys:
        [NSArray arrayWithObjects: @"subjectType", @"subjectText", nil]
        triggerChangeNotificationsForDependentKey: @"subjectInputHTML"];
	
	[pool release];
}

- (void)awakeFromNib
{
	[KSEmailAddressComboBox setWillAddAnonymousEntry:NO];
	[KSEmailAddressComboBox setWillIncludeNames:NO];

	// Correct the spacing of the custom labels form
	NSSize spacing = [oCustomLabelsForm intercellSpacing];
	spacing.height = 4;
	[oCustomLabelsForm setIntercellSpacing:spacing];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(focusMessageField:)
												 name:@"AddedMessageField"
											   object:oArrayController];
}

- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewObject
{
	KTAbstractElement *element = [self delegateOwner];
	
	if (isNewObject)
	{
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		
		// Set up default bunch of fields
		NSString *language = [[self elementPlugInContainer] languageCode];
		NSMutableArray *fields = [NSMutableArray array];
		
		ContactElementField *aField = [[ContactElementField alloc] initWithIdentifier:@"visitorName"];
		[aField setLabel:[[self bundle] localizedStringForString:@"Name" language:language]];
		[aField setType:ContactElementTextFieldField];
		[fields addObject:aField];
		[aField release];
		
		aField = [[ContactElementField alloc] initWithIdentifier:@"email"];
		[aField setLabel:[[self bundle] localizedStringForString:@"Email" language:language]];
		[aField setType:ContactElementTextFieldField];
		
		[aField setDefaultString:[defaults objectForKey:@"emailPlaceholder"]];
		[fields addObject:aField];
		[aField release];
		
		aField = [[ContactElementField alloc] initWithIdentifier:@"subject"];
		[aField setLabel:[[self bundle] localizedStringForString:@"Subject" language:language]];
		[aField setType:ContactElementTextFieldField];
		[fields addObject:aField];
		[aField release];
		
		aField = [[ContactElementField alloc] initWithIdentifier:@"message"];
		[aField setLabel:[[self bundle] localizedStringForString:@"Message" language:language]];
		[aField setType:ContactElementTextAreaField];
		[fields addObject:aField];
		[aField release];
		
		aField = [[ContactElementField alloc] initWithIdentifier:@"send"];
		[aField setLabel:[[self bundle] localizedStringForString:@"Send" language:language]];
		[aField setType:ContactElementSubmitButton];
		[fields addObject:aField];
		[aField release];
		
		[self setFields:fields];
	}
	
	myPluginProperties = [element retain];
	[myPluginProperties addObserver:self forKeyPath:@"fields" options:0 context:NULL];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[myPluginProperties removeObserver:self forKeyPath:@"fields"];
	[myPluginProperties release];
	[myEmailField release];
	[myFields release];
	
	[super dealloc];
}

+ (NSSet *)plugInKeys
{
	return [NSSet setWithObjects:nil];	
}

+ (Class)inspectorViewControllerClass { return [ContactElementInspectorController class]; }


#pragma mark -
#pragma mark Language

/*!	Figures out the language dictionary based upon the site's language.
*/
- (NSDictionary *)languageDictionary
{
	static NSDictionary *sLocalizations = nil;
	if (nil == sLocalizations)
	{
		sLocalizations = [[NSDictionary alloc] initWithContentsOfFile:[[self bundle] pathForResource:@"ContactStrings" ofType:@"plist"]];
	}
	
	NSString *languageCode = [[self elementPlugInContainer] languageCode];
	
	NSDictionary *result = [sLocalizations objectForKey:languageCode];
	
	
	// if not found, try the langauge without a region, e.g. fr-CA -> fr
	if (nil == result)
	{
		unsigned int whereDash = [languageCode rangeOfString:@"-"].location;
		if (NSNotFound != whereDash)
		{
			languageCode = [languageCode substringToIndex:whereDash];
			result = [sLocalizations objectForKey:languageCode];
		}
	}
	// TO DO ... try the current langauge
	
	
	// Last Resort, try English
	if (nil == result)
	{
		result = [sLocalizations objectForKey:@"en"];
	}
	return result;
}

#pragma mark -
#pragma mark KVO

/*	We observe the fields array in case anyone else changes it for us (e.g. undo/redo)
 *	Check to make sure this isn't because we're currently archiving the fields array, and if so
 *	update our in-memory store.
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (object == myPluginProperties && [keyPath isEqualToString:@"fields"] && !myIsArchivingFields)
	{
		[self setFields:[self fieldsByFetchingFromPluginProperties] archiveToPluginProperties:NO];
	}
}


- (void)focusMessageField:(NSNotification *)aNotification	// AddedMessageField notification
{
	[[oLabel window] makeFirstResponder:oLabel];
}

#pragma mark -
#pragma mark Labels

/*	All of these accessor methods fallback to using the -languageDictionary if no
 *	suitable value is found.
 */

- (NSString *)sendButtonTitle
{
	NSString *result = [[self delegateOwner] objectForKey:@"sendButtonTitle"];
	if (nil == result)
	{
		result = [[self languageDictionary] objectForKey:@"Send"];
	}
	return result;
}

- (void)setSendButtonTitle:(NSString *)anAddress
{
	[[self delegateOwner] setObject:anAddress forKey:@"sendButtonTitle"];
}

- (NSString *)subjectLabel
{
	NSString *result = [[self delegateOwner] objectForKey:@"subjectLabel"];
	if (nil == result)
	{
		result = [[self languageDictionary] objectForKey:@"Subject:"];
	}
	return result;
}

- (void)setSubjectLabel:(NSString *)anAddress
{
	[[self delegateOwner] setObject:anAddress forKey:@"subjectLabel"];
}

- (NSString *)emailLabel
{
	NSString *result = [[self delegateOwner] objectForKey:@"emailLabel"];
	if (nil == result)
	{
		result = [[self languageDictionary] objectForKey:@"EMail:"];
	}
	return result;
}

- (void)setEmailLabel:(NSString *)anAddress
{
	[[self delegateOwner] setObject:anAddress forKey:@"emailLabel"];
}

- (NSString *)nameLabel
{
	NSString *result = [[self delegateOwner] objectForKey:@"nameLabel"];
	if (nil == result)
	{
		result = [[self languageDictionary] objectForKey:@"Name:"];
	}
	return result;
}

- (void)setNameLabel:(NSString *)anAddress
{
	[[self delegateOwner] setObject:anAddress forKey:@"nameLabel"];
}

- (NSString *)messageLabel
{
	NSString *result = [[self delegateOwner] objectForKey:@"messageLabel"];
	if (nil == result)
	{
		result = [[self languageDictionary] objectForKey:@"Message:"];
	}
	return result;
}

- (void)setMessageLabel:(NSString *)anAddress
{
	[[self delegateOwner] setObject:anAddress forKey:@"messageLabel"];
}

#pragma mark -
#pragma mark Simple Accessors

/*!	Should labels go on the side? (if not, then above the fields)
*/
- (BOOL)sideLabels
{
    return [[self delegateOwner] boolForKey:@"sideLabels"];
}

- (void)setSideLabels:(BOOL)aSideLabels
{
	[[self delegateOwner] setBool:aSideLabels forKey:@"sideLabels"];
}

- (int) subjectType
{
    return [[self delegateOwner] integerForKey:@"subjectType"];
}

- (void)setSubjectType:(int)aSubjectType
{
	[[self delegateOwner] setInteger:aSubjectType forKey:@"subjectType"];
}

- (NSString *)subjectText
{
	return [[self delegateOwner] objectForKey:@"subjectText"];
}

- (void)setSubjectText:(NSString *)anAddress
{
	[[self delegateOwner] setObject:anAddress forKey:@"subjectText"];
}



#pragma mark -
#pragma mark Derived Accessors

- (NSString *)CSSURLs
{
	NSURL *designURL = [[[self page] master] designDirectoryURL];
    NSURL *mainCSSURL = [designURL URLByAppendingPathComponent:@"main.css" isDirectory:NO];
	NSURL *masterCSSURL = [designURL URLByAppendingPathComponent:@"master.css" isDirectory:NO];
	
    NSString *result = [NSString stringWithFormat:@"%@ %@", [mainCSSURL absoluteString], [masterCSSURL absoluteString]];
    return result;
}

- (NSString *)subjectPrompt
{
	NSString *result = nil;
	switch([self subjectType])
	{
		case kKTContactSubjectField:
			result = LocalizedStringInThisBundle(@"Suggested Subject (optional)",
									   @"Label for subject field when it will be a text field");
			break;
		case kKTContactSubjectSelection:
			result = LocalizedStringInThisBundle(@"List of Subjects (separate by commas)",
									   @"Label for subject field when it will be a selection menu");
			break;
		case kKTContactSubjectHidden:
			result = LocalizedStringInThisBundle(@"Fixed Subject for all messages",
									   @"Label for subject field when it will be hidden");
			break;
	}
	return result;
}

- (void)setSubjectPrompt:(NSString *)aPrompt
{
	[self shouldNotImplement:_cmd];
}

- (NSString *)subjectInputHTML
{
	NSString *result = nil;
	NSString *subjectText = [self subjectText];
	if (nil == subjectText)
	{
		subjectText = @"";
	}
	switch([self subjectType])
	{
		case kKTContactSubjectField:
			result = [NSString stringWithFormat:@"<input id=\"s%@\" name=\"s\" type=\"text\" value=\"%@\" />", 
				[((KTAbstractElement *)[self delegateOwner]) uniqueID], [subjectText stringByEscapingHTMLEntities]];
			break;
		case kKTContactSubjectSelection:
		{
			NSMutableString *buf = [NSMutableString string];
			
			// Break into lines, and for each line, break into comma separated.
			NSArray *lineArray = [subjectText componentsSeparatedByLineSeparators];
			NSEnumerator *theEnum = [lineArray objectEnumerator];
			NSString *oneLine;

			[buf appendFormat:@"<select id=\"s%@\" name=\"s\">", [((KTAbstractElement *)[self delegateOwner]) uniqueID]];
			while (nil != (oneLine = [theEnum nextObject]) )
			{
				NSArray *commaArray = [oneLine componentsSeparatedByCommas];
				NSEnumerator *theEnum = [commaArray objectEnumerator];
				NSString *oneItem;

				while (nil != (oneItem = [theEnum nextObject]) )
				{
					NSString *trimmedItem = [oneItem trim];
					if (![trimmedItem isEqualToString:@""])
					{
						[buf appendFormat:[NSString stringWithFormat:@"<option>%@</option>",
							[trimmedItem stringByEscapingHTMLEntities]]];
					}
				}
				
			}
			[buf appendString:@"</select>"];
			result = [NSString stringWithString:buf];
			break;
		}
		case kKTContactSubjectHidden:
			result = [NSString stringWithFormat:@"<input id=\"s%@\" name=\"s\" type=\"hidden\" value=\"%@\" />", 
				[((KTAbstractElement *)[self delegateOwner]) uniqueID], [subjectText stringByEscapingHTMLEntities]];
			break;
	}
	
	return result;
}

- (void)setSubjectInputHTML:(NSString *)anHTML
{
	[self shouldNotImplement:_cmd];
}

#define MAX_EMAILS_LENGTH 256

- (NSString *)encodedRecipient
{
	
	NSString *email = [[self delegateOwner] valueForKey:@"address"];
	
	NSData *mailData = [email dataUsingEncoding:NSUTF8StringEncoding];
	unsigned char outBytes[MAX_EMAILS_LENGTH] = { 0 };
	unsigned char inBytes[MAX_EMAILS_LENGTH] = { 0 };
	// fill with zeros.  Make the buffer have zeros afterwards to prevent possible encoding problems
	// where there's junk at the end.
	
	[mailData getBytes:inBytes];

	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *passwordString = [defaults objectForKey:@"mailmePassword"];
	if (nil == passwordString)
	{
		passwordString = CONTACT_PASSWORD;
	}
	const char *password = [passwordString UTF8String];
	BF_KEY key;
	BF_set_key(&key, (int) strlen(password), (unsigned char *) password);
	
	unsigned char ivec[8] = { 0,0,0,0, 0,0,0,0 };
	int num = 0;
	
	BF_cfb64_encrypt(inBytes,					// in
					 outBytes,					// out
					 [mailData length] + 2,		// length ... 2 extra 0's to keep junk from appearing at end???
					 &key,						// schedule (key)
					 (unsigned char *) &ivec,	// ivec
					 &num,						// num
					 BF_ENCRYPT);				// encode vs. decode
	
	// Brute force -- trim ending zeroes off of the end of the string
	int newLength = MAX_EMAILS_LENGTH-1;
	while (0 == outBytes[newLength])
	{
		newLength--;
	}
	
	NSData *trimmedData = [NSData dataWithBytes:outBytes length:newLength];
	NSString *result = [trimmedData base64Encoding];

//	LOG((@"Encrypted %@ as %@ --> %@", email, trimmedData, result ));

#ifdef DEBUG
    [self decode:result];
#endif    
	return result;
}

#ifdef DEBUG

- (void)decode:(NSString *)v
{
    NSData *decodedTrimmedData = [NSData dataWithBase64EncodedString:v];

    unsigned char outBytes[MAX_EMAILS_LENGTH];
	unsigned char inBytes[MAX_EMAILS_LENGTH] = { 0 };
    [decodedTrimmedData getBytes:inBytes];
    
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *passwordString = [defaults objectForKey:@"mailmePassword"];
	if (nil == passwordString)
	{
		passwordString = CONTACT_PASSWORD;
	}
	const char *password = [passwordString UTF8String];
	
	BF_KEY key;
	BF_set_key(&key, (int) strlen(password), (unsigned char *) password);


    unsigned char ivec[8] = { 0,0,0,0, 0,0,0,0 };
	int num = 0;
	
	BF_cfb64_encrypt(inBytes,					// in
					 outBytes,					// out
					 [decodedTrimmedData length],	// length
					 &key,						// schedule (key)
					 (unsigned char *) &ivec,	// ivec
					 &num,						// num
					 BF_DECRYPT);				// encode vs. decode
    
//    NSString *decryptedEmail = [NSString stringWithCString:(const char *)outBytes encoding:NSUTF8StringEncoding]; // encoding should match the encoding of mailData, above, shouldn't it???
//	NSLog(@"Decrypted %@ --> %@ as %@", v, decodedTrimmedData, decryptedEmail);
}
#endif


- (void)setEncodedRecipient:(NSString *)anEnc
{
	[self shouldNotImplement:_cmd];
}

// For the subjects text field, allow return to insert a newline.

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector
{
    BOOL retval = NO;
    if ( (control == oSubjects)
		&& (commandSelector == @selector(insertNewline:) ) )
	{
        retval = YES;
        [textView insertNewlineIgnoringFieldEditor:nil];
    }
    return retval;
}

#pragma mark *** NEW STUFF ***

/*! URL - The defaults bit allows users to override it.
*/
- (NSString *)mailmeURL
{
	NSString *result = [[NSUserDefaults standardUserDefaults] objectForKey:@"mailmeURL"];
	if (nil == result) {
		result = @"http://service.karelia.com/mailme.php";
	}
	return result;
}

- (NSString *)mailmeAjaxURL
{
	NSString *result = [[NSUserDefaults standardUserDefaults] objectForKey:@"mailmeAjaxURL"];
	if (nil == result) {
		result = @"http://service.karelia.com/mailmeAjax.php";
	}
	return result;
}

#pragma mark -
#pragma mark Fields

/*	We will be managing KVO notifications of the fields array ourself
 */
+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key
{
	if ([key isEqualToString:@"fields"])
	{
		return NO;
	}
	else
	{
		return [super automaticallyNotifiesObserversForKey:key];
	}
}

- (ContactElementField *)contactField
{
	(void) [self fields];	// make sure loaded
	return myEmailField;
}


- (NSArray *)fields
{
	// If there currently is no array, pull it out of the delegateOwner
	if (!myFields)
	{
		[self setFields:[self fieldsByFetchingFromPluginProperties] archiveToPluginProperties:NO];
	}
	
	return myFields;
}

- (void)setFields:(NSArray *)fields;
{
	[self setFields:fields archiveToPluginProperties:YES];
}

- (void)setFields:(NSArray *)fields archiveToPluginProperties:(BOOL)archive
{
	[self willChangeValueForKey:@"fields"];
	
	// Remove us as the owner of the previous fields array
	[myFields makeObjectsPerformSelector:@selector(setOwner:) withObject:nil];
	
	// Hang on to the real fields array, and store a dictionary representation of it
	fields = [fields copy];
	[myFields release];
	myFields = fields;
	
	if (archive)
	{
		myIsArchivingFields = YES;
		[[self delegateOwner] setObject:[self fieldsPropertyListRepresentation]
									forKey:@"fields"];
		myIsArchivingFields = NO;
	}
	
	// Set us as the owner of the new fields array
	[myFields makeObjectsPerformSelector:@selector(setOwner:) withObject:self];
	
	[self didChangeValueForKey:@"fields"];
}

/*	Returns the list of fields as property list suitable for archiving
 */
- (NSArray *)fieldsPropertyListRepresentation
{
	return [[self fields] valueForKey:@"dictionaryRepresentation"];
}

/*	Retrieves the fields plist representation from the delegateOwner and converts it to real
 *	ContactFormField objects.
 */
- (NSArray *)fieldsByFetchingFromPluginProperties
{
	NSArray *dictionaries = [[self delegateOwner] objectForKey:@"fields"];
	NSMutableArray *result = [NSMutableArray arrayWithCapacity:[dictionaries count]];
	
	NSEnumerator *enumerator = [dictionaries objectEnumerator];
	NSDictionary *dictionary;
	while (dictionary = [enumerator nextObject])
	{
		ContactElementField *field = [[ContactElementField alloc] initWithDictionary:dictionary];
		[result addObject:field];
		[field release];
		
		// Get the email field
		if ([[field identifier] isEqualToString:@"email"])
		{
			[myEmailField release];
			myEmailField = [field retain];
		}
	}
	
	return result;
}

#pragma mark -
#pragma mark Data Migrator

- (BOOL)importPluginProperties:(NSDictionary *)oldPluginProperties
                    fromPlugin:(NSManagedObject *)oldPlugin
                         error:(NSError **)error
{
    KTAbstractElement *element = [self delegateOwner];
    
    // Import basic properties
    [element setValuesForKeysWithDictionary:oldPluginProperties];
    
    
    // Setup the subject field
    ContactElementField *subjectField = [[self fields] objectAtIndex:2];
    
    NSString *oldSubjectText = [oldPluginProperties valueForKey:@"subjectText"];
    switch ([oldPluginProperties integerForKey:@"subjectType"])
    {
        case 0:     // kKTContactSubjectHidden
            [subjectField setType:ContactElementHiddenField];
            [subjectField setDefaultString:oldSubjectText];
            break;
        
        case 1:     // kKTContactSubjectField
            [subjectField setType:ContactElementTextFieldField];
            [subjectField setDefaultString:oldSubjectText];
            break;
            
        case 2:     // kKTContactSubjectSelection
        {
            [subjectField setType:ContactElementPopupButtonField];
            
            NSMutableArray *options = [NSMutableArray array];
            NSEnumerator *lines = [[oldSubjectText componentsSeparatedByLineSeparators] objectEnumerator];
            NSString *aLine;
            while (aLine = [lines nextObject])
            {
                NSEnumerator *components = [[aLine componentsSeparatedByCommas] objectEnumerator];
                NSString *aComponent;
                while (aComponent = [components nextObject])
                {
                    [options addObject:aComponent];
                }
            }
            [subjectField setVisitorChoices:options];
            
            break;
        }
    }
    
    
    // Setup labels
    NSString *aLabel = [oldPluginProperties valueForKey:@"subjectLabel"];
    if (aLabel) [[[self fields] objectAtIndex:2] setLabel:aLabel];
    
    aLabel = [oldPluginProperties valueForKey:@"emailLabel"];
    if (aLabel) [[[self fields] objectAtIndex:1] setLabel:aLabel];
    
    aLabel = [oldPluginProperties valueForKey:@"nameLabel"];
    if (aLabel) [[[self fields] objectAtIndex:0] setLabel:aLabel];
    
    aLabel = [oldPluginProperties valueForKey:@"messageLabel"];
    if (aLabel) [[[self fields] objectAtIndex:3] setLabel:aLabel];
    
    aLabel = [oldPluginProperties valueForKey:@"sendButtonTitle"];
    if (aLabel) [[[self fields] objectAtIndex:4] setLabel:aLabel];
    
    
    
    // We have to force the fields to be updated persistently as there's no array controller involved
    [self setFields:[self fields] archiveToPluginProperties:YES];
    
    
    return YES;
}

@end
