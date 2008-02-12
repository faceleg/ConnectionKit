//
//  NSCharacterSet+KTExtensions.m
//  KTComponents
//
//  Created by Dan Wood on 11/18/04.
//  Copyright 2004 Karelia Software, LLC. All rights reserved.
//

#import "NSCharacterSet+KTExtensions.h"

static NSCharacterSet *sAlphanumericASCIICharacterSet;
static NSCharacterSet *sAlphanumericASCIIUnderlineCharacterSet;
static NSCharacterSet *sFullWhitespaceAndNewlineCharacterSet;
static NSCharacterSet *sFullNewlineCharacterSet;
static NSCharacterSet *sLegalPageTitleCharacterSet;
static NSCharacterSet *sPrescreenIllegalCharacterSet;

@implementation NSCharacterSet ( KTExtensions )

+ (NSCharacterSet *)alphanumericASCIICharacterSet;
{
	if (nil == sAlphanumericASCIICharacterSet)
	{
		NSMutableCharacterSet *set = [[[NSMutableCharacterSet alloc] init] autorelease];
		
		[set addCharactersInRange:NSMakeRange('A', 26)];
		[set addCharactersInRange:NSMakeRange('a', 26)];
		[set addCharactersInRange:NSMakeRange('0', 10)];

		sAlphanumericASCIICharacterSet = [set copy];		// retain a non-mutable copy
	}
	return sAlphanumericASCIICharacterSet;
}

// Be pretty restrictive to make our URLs pretty.  Just ASCII alphanumeric, plus a few punctuations not used
+ (NSCharacterSet *)legalPageTitleCharacterSet;
{
	if (nil == sLegalPageTitleCharacterSet)
	{
		NSMutableCharacterSet *legalPageTitleCharacterSet = [[[NSMutableCharacterSet alloc] init] autorelease];
		
		[legalPageTitleCharacterSet formUnionWithCharacterSet:[NSCharacterSet alphanumericASCIICharacterSet]];

		[legalPageTitleCharacterSet addCharactersInString:@"-_"];
		sLegalPageTitleCharacterSet = [legalPageTitleCharacterSet copy];		// retain a non-mutable copy
	}
	return sLegalPageTitleCharacterSet;
}

// Variant of above, but all alpha characters.  I need to pre-filter to this before downsampling page URL titles to alpha.
// Note: Space is legal, since that gets converted to _ later.
+ (NSCharacterSet *)prescreenIllegalCharacterSet;
{
	if (nil == sPrescreenIllegalCharacterSet)
	{
		NSMutableCharacterSet *prescreenIllegalCharacterSet = [[[NSMutableCharacterSet alloc] init] autorelease];
		
		[prescreenIllegalCharacterSet formUnionWithCharacterSet:[NSCharacterSet alphanumericCharacterSet]];
		
		[prescreenIllegalCharacterSet addCharactersInString:@"-_ "];
		[prescreenIllegalCharacterSet invert];
		sPrescreenIllegalCharacterSet = [prescreenIllegalCharacterSet copy];		// retain a non-mutable copy
	}
	return sPrescreenIllegalCharacterSet;
}

		
+ (NSCharacterSet *)fullWhitespaceAndNewlineCharacterSet
{
	if (nil == sFullWhitespaceAndNewlineCharacterSet)
	{
		unichar chars[] = { ' ','\t','\r','\n', 0x0085, 0x00a0, 0x200b, 0x2028, 0x2029, 0xFFFC };
		// BE SURE LENGTH OF ABOVE ARRAY MATCHES NUMBER BELOW!
		
		NSString *whiteString = [NSString stringWithCharacters:chars length:9];
		sFullWhitespaceAndNewlineCharacterSet =
			[[NSCharacterSet characterSetWithCharactersInString:whiteString] retain];
	}
	return sFullWhitespaceAndNewlineCharacterSet;
}

+ (NSCharacterSet *)nonWhitespaceAndNewlineCharacterSet
{
	static NSCharacterSet *result;
	
	if (!result)
	{
		result = [[[NSCharacterSet fullWhitespaceAndNewlineCharacterSet] invertedSet] retain];
	}
	
	return result;
}

+ (NSCharacterSet *)fullNewlineCharacterSet
{
	if (nil == sFullNewlineCharacterSet)
	{
		unichar chars[] = { '\r','\n', 0x0085, 0x2028, 0x2029, 0xFFFC };
		// BE SURE LENGTH OF ABOVE ARRAY MATCHES NUMBER BELOW!
		
		NSString *whiteString = [NSString stringWithCharacters:chars length:6];
		sFullNewlineCharacterSet =
			[[NSCharacterSet characterSetWithCharactersInString:whiteString] retain];
	}
	return sFullNewlineCharacterSet;
}

// Return ASCII alphanumeric + underline

+ (NSCharacterSet *)alphanumericASCIIUnderlineCharacterSet
{
	if (nil == sAlphanumericASCIIUnderlineCharacterSet)
	{
		NSMutableCharacterSet *set = [[[NSMutableCharacterSet alloc] init] autorelease];
		[set formUnionWithCharacterSet:[NSCharacterSet alphanumericASCIICharacterSet]];
		[set addCharactersInString:@"_"];
		sAlphanumericASCIIUnderlineCharacterSet = [set copy];		// retain a non-mutable copy
	}
	return sAlphanumericASCIIUnderlineCharacterSet;
}

#pragma mark -
#pragma mark Instance Methods

- (NSCharacterSet *)setByAddingCharactersInString:(NSString *)aString
{
	NSMutableCharacterSet *mutableSet = [self mutableCopyWithZone:[self zone]];
	[mutableSet addCharactersInString:aString];
	NSCharacterSet *result = [[mutableSet copy] autorelease];
	[mutableSet release];
	return result;
}

- (NSCharacterSet *)setByRemovingCharactersInString:(NSString *)aString
{
	NSMutableCharacterSet *mutableSet = [self mutableCopyWithZone:[self zone]];
	[mutableSet removeCharactersInString:aString];
	NSCharacterSet *result = [[mutableSet copy] autorelease];
	[mutableSet release];
	return result;
}


@end
