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

#import "ContactPlugIn.h"

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

@interface ContactPlugIn ()

- (NSArray *)fieldsPropertyListRepresentation;
- (NSArray *)fieldsByFetchingFromPluginProperties;

#ifdef DEBUG
- (void)decode:(NSString *)v;
#endif
@end


@implementation ContactPlugIn

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
	

    [ContactPlugIn setKeys:
        [NSArray arrayWithObjects: @"address", nil]
        triggerChangeNotificationsForDependentKey: @"encodedRecipient"];
	[ContactPlugIn setKeys:
        [NSArray arrayWithObjects: @"subjectType", nil]
        triggerChangeNotificationsForDependentKey: @"subjectPrompt"];
	[ContactPlugIn setKeys:
        [NSArray arrayWithObjects: @"subjectType", @"subjectText", nil]
        triggerChangeNotificationsForDependentKey: @"subjectInputHTML"];
	
	[pool release];
}

+ (NSArray *)plugInKeys;
{
    return [NSArray arrayWithObjects:@"fields", @"address", @"copyToSender", @"sendButtonTitle", @"subjectLabel", @"emailLabel", @"nameLabel", @"messageLabel", @"sideLabels", @"subjectType", @"subjectText", nil];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_emailField release];
	[_fields release];
	
	[super dealloc];
}

#pragma mark Labels

/*	All of these accessor methods fallback to using the -languageDictionary if no
 *	suitable value is found.
 */

- (void)didAddToPage:(id <SVPage>)page;
{
    // Create initial fields if needed
    if (![self fields])
	{
        // Want to localize field labels according to the site…
		NSString *languageCode = [page language];
        NSDictionary *localizations = [[NSDictionary alloc] initWithContentsOfFile:[[self bundle] pathForResource:@"ContactStrings" ofType:@"plist"]];
        NSDictionary *localizedStrings = [localizations objectForKey:languageCode];
        
		// …if not found, try the langauge without a region, e.g. fr-CA -> fr
        if (!localizedStrings)
        {
            unsigned int whereDash = [languageCode rangeOfString:@"-"].location;
            if (NSNotFound != whereDash)
            {
                languageCode = [languageCode substringToIndex:whereDash];
                localizedStrings = [localizations objectForKey:languageCode];
            }
        }
        
        // TO DO ... try the current langauge
        
        // …last resort, try English
        if (!localizedStrings) localizedStrings = [localizations objectForKey:@"en"];
        
        
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		
        // Set up default bunch of fields
		NSMutableArray *fields = [NSMutableArray array];
		
		ContactElementField *aField = [[ContactElementField alloc] initWithIdentifier:@"visitorName"];
		[aField setLabel:[localizedStrings objectForKey:@"Name:"]];
		[aField setType:ContactElementTextFieldField];
		[fields addObject:aField];
		[aField release];
		
		aField = [[ContactElementField alloc] initWithIdentifier:@"email"];
		[aField setLabel:[localizedStrings objectForKey:@"EMail:"]];
		[aField setType:ContactElementTextFieldField];
		
		[aField setDefaultString:[defaults objectForKey:@"emailPlaceholder"]];
		[fields addObject:aField];
		[aField release];
		
		aField = [[ContactElementField alloc] initWithIdentifier:@"subject"];
		[aField setLabel:[localizedStrings objectForKey:@"Subject:"]];
		[aField setType:ContactElementTextFieldField];
		[fields addObject:aField];
		[aField release];
		
		aField = [[ContactElementField alloc] initWithIdentifier:@"message"];
		[aField setLabel:[localizedStrings objectForKey:@"Message:"]];
		[aField setType:ContactElementTextAreaField];
		[fields addObject:aField];
		[aField release];
		
		aField = [[ContactElementField alloc] initWithIdentifier:@"send"];
		[aField setLabel:[localizedStrings objectForKey:@"Send"]];
		[aField setType:ContactElementSubmitButton];
		[fields addObject:aField];
		[aField release];
		
		[self setFields:fields];
        [localizedStrings release];
	}
}

@synthesize sendButtonTitle = _sendButtonTitle;
@synthesize subjectLabel = _subjectLabel;
@synthesize emailLabel = _emailLabel;
@synthesize nameLabel = _nameLabel;
@synthesize messageLabel = _messageLabel;

@synthesize sideLabels = _sideLabels;
@synthesize subjectType = _subjectType;
@synthesize subjectText = _subjectText;

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
				[([self delegateOwner]) uniqueID], [subjectText stringByEscapingHTMLEntities]];
			break;
		case kKTContactSubjectSelection:
		{
			NSMutableString *buf = [NSMutableString string];
			
			// Break into lines, and for each line, break into comma separated.
			NSArray *lineArray = [subjectText componentsSeparatedByLineSeparators];
			NSEnumerator *theEnum = [lineArray objectEnumerator];
			NSString *oneLine;

			[buf appendFormat:@"<select id=\"s%@\" name=\"s\">", [[self delegateOwner] uniqueID]];
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
				[[self delegateOwner] uniqueID], [subjectText stringByEscapingHTMLEntities]];
			break;
	}
	
	return result;
}

- (void)setSubjectInputHTML:(NSString *)anHTML
{
	[self shouldNotImplement:_cmd];
}

@synthesize address = _address;
@synthesize copyToSender = _copyToSender;

#define MAX_EMAILS_LENGTH 256

- (NSString *)encodedRecipient
{
	
	NSString *email = [self address];
	
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

#pragma mark Fields

- (ContactElementField *)contactField
{
	return _emailField;
}

@synthesize fields = _fields;

/*	Retrieves the fields plist representation from the delegateOwner and converts it to real
 *	ContactFormField objects.
 */
- (void)setFields:(NSArray *)fields;
{
	fields = [fields copy];
    [_fields release]; _fields = fields;
    
    for (ContactElementField *aField in fields)
    {
        if ([[aField identifier] isEqualToString:@"email"])
		{
			[_emailField release]; _emailField = [aField retain];
		}
    }
}

/*	Returns the list of fields as property list suitable for archiving
 */
- (NSArray *)fieldsPropertyListRepresentation
{
	return [[self fields] valueForKey:@"dictionaryRepresentation"];
}

@end
