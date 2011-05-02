//
//  RegGenerator.m
//  GenRegistration
//
//  Created by Dan Wood on 11/11/05.
//  Copyright 2005-2011 Karelia Software. All rights reserved.
//

#import "RegGenerator.h"
#include <openssl/sha.h>

#define SHA1_CTX			SHA_CTX
#define SHA1_DIGEST_LENGTH	SHA_DIGEST_LENGTH


@implementation NSString ( Something )

- (NSString *) condenseWhiteSpace	// remove runs of spaces, newlines, etc.
									// replacing with a single space
{
	return [self condenseMultipleCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] into:' '];
}

- (NSString *) removeCharactersInSet:(NSCharacterSet *)aBadSet
{
	NSString *result = nil;
	unsigned len = [self length];
	unichar *buffer = malloc(len * sizeof(unichar));
	unsigned i;
	unsigned j = 0;
	for ( i = 0 ; i < len ; i++ )
	{
		unichar c = [self characterAtIndex:i];
		if (![aBadSet characterIsMember:c])
		{
			buffer[j++] = c;
		}
	}
	result = [[[NSString alloc] initWithCharacters:buffer length:j] autorelease];
	free(buffer);
	return result;
}

/*"	Return a string where runs of multiple white space characters (space, tab, all types of newline, return, forced space, and Unicode U+FFFC, Object replacement character) are condensed down to a single space.  Trim off any leading/trailing white space.
"*/

- (NSString *) condenseMultipleCharactersFromSet:(NSCharacterSet *)aMultipleSet into:(unichar)aReplacement;
{
	NSString *result = self;
	if (![self isEqualToString:@""])
	{
		unsigned len = [self length];
		unichar *buffer = malloc(len * sizeof(unichar));
		unsigned i;
		unsigned j = 0;
		BOOL wasTargetChar = YES;		// initialize to true; making any initial white space *ignored*
		for ( i = 0 ; i < len ; i++ )
		{
			unichar c = [self characterAtIndex:i];
			if ([aMultipleSet characterIsMember:c])
			{
				if (!wasTargetChar)
				{
					wasTargetChar = YES;	// don't allow multiple in a row
					buffer[j++] = aReplacement;		// replace with a space
				}
				// ignore if the last one was whitespace
			}
			else
			{
				wasTargetChar = NO;
				buffer[j++] = c;
			}
		}
		if (wasTargetChar && (j > 0))	// was the last character white space?
		{
			j -= 1;
		}
		result = [[[NSString alloc] initWithCharacters:buffer length:j] autorelease];
		free(buffer);
	}
	
	return result;
}	


- (NSString *) stringByRemovingCharactersInSet:(NSCharacterSet *)set
{
	NSString *result = nil;
	unsigned len = [self length];
	unichar *buffer = malloc(len * sizeof(unichar));
	unsigned i;
	unsigned j = 0;
	for ( i = 0 ; i < len ; i++ )
	{
		unichar c = [self characterAtIndex:i];
		if (![set characterIsMember:c])
		{
			buffer[j++] = c;
		}
	}
	result = [[[NSString alloc] initWithCharacters:buffer length:j] autorelease];
	free(buffer);
	return result;
}
@end


@implementation NSArray (randomness)
- (id) randomObject;
{
	int count = [self count];
	int index = random() % count;
	return [self objectAtIndex:index];
}
@end

#pragma mark -
#pragma mark Main Work

@implementation RegGenerator

+ (NSString *)hashStringFromLicenseString:(NSString *)aCode
{
	NSMutableString *buf = [NSMutableString stringWithString:@"{ "];
	NSString *cleanedString = [[aCode removeCharactersInSet:[[NSCharacterSet letterCharacterSet] invertedSet]] lowercaseString];
	const char *string = [cleanedString UTF8String];
	
	SHA1_CTX ctx;
	unsigned char digest[SHA1_DIGEST_LENGTH];
	SHA1_Init(&ctx);
	SHA1_Update(&ctx, string, strlen(string));
	SHA1_Final(digest, &ctx);
	int i;
	for (i = 0 ; i < SHA1_DIGEST_LENGTH; i++ )
	{
		[buf appendFormat:@"0x%02X,", digest[i]];
	}
	[buf deleteCharactersInRange:NSMakeRange([buf length] - 1, 1)];	// take off last 2 chars
	[buf appendFormat:@" }, // %@", aCode];
	return [NSString stringWithString:buf];
}


+ (NSString *)generateLicenseCodeFromWords:(NSArray *)keywords
									  name:(BOOL)aNamed
									  pro:(BOOL)aPro
								 licensee:(NSString *)aLicensee	// N/A if anonymous
							 licenseIndex:(int)anIndex			// N/A if not anonymous
								  version:(int)aVersion			// 0 = trial, expires in future
									 date:(NSDate *)aDate		// future for trial versions
							  licenseType:(int)aLicenseType
									 seats:(int)aSeats
							licenseSource:(int)aLicenseSource
							 returningHash:(NSString **)outHash;
{
	NSMutableArray *keys = [NSMutableArray array];		// output
	
	if (aNamed)
	{
		NSString *condensedLicensee = [aLicensee condenseWhiteSpace];	// we don't want newlines, multiple spaces, etc.
		[keys addObject:condensedLicensee];
	}
	else
	{
		unsigned char indexLow = anIndex % 256;
		unsigned char indexHigh = anIndex / 256;
		// Add a word corresponding to a random number, and a word corresponding to it PLUS ONE
		[keys addObject:[[[keywords objectAtIndex:indexLow] randomObject] capitalizedString]];
		[keys addObject:[[[keywords objectAtIndex:indexHigh] randomObject] capitalizedString]];
	}

	// Add site license seat count ... this will always be before the date.
	
	if (aLicenseType == siteLicense)
	{
		[keys addObject:[[[keywords objectAtIndex:aSeats] randomObject] capitalizedString]];
	}
		
	// Add the date as number of fortnights since a reference date (almost 10 years accuracy)
	
	float secondsPerFortnight = 14 * 24 * 60 * 60;
	NSTimeInterval sinceRefDate = [aDate timeIntervalSinceDate:[NSDate dateWithString:REFERENCE_TIMESTAMP]];
	int fortnights = sinceRefDate / secondsPerFortnight ;
	fortnights = MAX(fortnights, 0);
	fortnights = MIN(fortnights, 255);
	
	[keys addObject:[[[keywords objectAtIndex:fortnights] randomObject] capitalizedString]];
	
	// Add license info mask:
	
	int licenseInfo = 
		(aVersion & versionMask)
		| ((aLicenseType * 8) & licenseMask)
		| (aLicenseSource ? paymentMask : 0)
		| (aPro ? proMask : 0)
		| (aNamed ? namedMask : 0);
	
	[keys addObject:[[[keywords objectAtIndex:licenseInfo] randomObject] capitalizedString]];
	
	// Add checksum of what we've accumulated to the end, mod 251 (a prime # that fits in 1 byte)
	long long stringChecksumTotal = 0;
	NSEnumerator *theEnum = [keys objectEnumerator];
	NSString *eachWord;
	
	while (nil != (eachWord = [theEnum nextObject]) )
	{
		NSString *lowerWord = [[eachWord lowercaseString] stringByRemovingCharactersInSet:[[NSCharacterSet letterCharacterSet] invertedSet]];
		int charIndex, length = [lowerWord length];
		for (charIndex = 0 ; charIndex < length ; charIndex++)
		{
			int c = [lowerWord characterAtIndex:charIndex] - 'a';
			stringChecksumTotal = stringChecksumTotal * 2 + c;		// shift each one by 1 bit
		}
	}
	
	int finalChecksum = stringChecksumTotal % the8BitPrime;
	[keys addObject:[[[keywords objectAtIndex:finalChecksum] randomObject] capitalizedString]];
	
	NSString *licenseString = [keys componentsJoinedByString:@" "];
	
	if (nil != outHash)
	{
		*outHash = [self hashStringFromLicenseString:licenseString];
	}
	return licenseString;
}


@end
