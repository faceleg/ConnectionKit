//
//  NSString+QuickLook.m
//  SandvoxQuickLook
//
//  Created by Dan Wood on 11/28/07.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "NSString+QuickLook.h"


@implementation NSString ( QuickLook )

/*!	Creates a string from HTML data in whatever encoding.  Handles UTF-16 and detection of the charset.  Reverts to plain ASCII.
 */
+ (NSString *)stringWithHTMLData:(NSData *)aData;
{
	NSStringEncoding enc = NSASCIIStringEncoding;	// Try this initially?
	
	// I'd like to try [NSString stringWithContentsOfFile:filePath usedEncoding:&enc error:&err]
	// for "sniffing" but it doesn't really work!  So I'll do this manually.
	unsigned short firstTwoBytes;
	[aData getBytes:&firstTwoBytes length:2];
	if (firstTwoBytes == 0xFFFE || firstTwoBytes == 0xFEFF)
	{
		enc = NSUnicodeStringEncoding;
	}
	else	// work with C strings here to find the charset=....." ... hope that's robust enough
	{
		int len = [aData length];
		if (len > 8)
		{
			char *bytes = (char *)[aData bytes];
			char *charset = strnstr(bytes, "charset=", len);
			if (0 != charset)
			{
				char *charsetStart = charset + strlen("charset=");
				char *endQuote = strnstr(charsetStart, "\"", 10);
				NSData *charsetData = [NSData dataWithBytes:charsetStart length:endQuote-charsetStart];
				NSString *charsetString = [[[NSString alloc] initWithData:charsetData encoding:NSASCIIStringEncoding] autorelease];
				enc = [charsetString encodingFromCharset];
			}
		}
	}
	NSString *string = [[[NSString alloc] initWithData:aData encoding:enc] autorelease];
	return string;
}


- (NSStringEncoding)encodingFromCharset
{
	CFStringEncoding cfEncoding
	= CFStringConvertIANACharSetNameToEncoding((CFStringRef)self);
	NSStringEncoding encoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding);
	return encoding;
}

/*
 Return the range of a substring, inclusively from starting to ending delimeters
 Original Source: <http://cocoa.karelia.com/Foundation_Categories/NSString/Return_the_range_of_20030523145602.m>
 (See copyright notice at <http://cocoa.karelia.com>)
 */

/*"	Find a string from one string to another with the default options; the delimeter strings are included in the result.
 "*/

- (NSRange)rangeFromString:(NSString *)inString1 toString:(NSString *)inString2
{
	return [self rangeFromString:inString1 toString:inString2 options:0];
}

/*"	Find a string from one string to another with the given options inMask; the delimeter strings %are included in the result.  The inMask parameter is the same as is passed to [NSString rangeOfString:options:range:].
 "*/

- (NSRange)rangeFromString:(NSString *)inString1 toString:(NSString *)inString2
				   options:(unsigned)inMask
{
	return [self rangeFromString:inString1 toString:inString2
                         options:inMask
                           range:NSMakeRange(0,[self length])];
}

/*"	Find a string from one string to another with the given options inMask and the given substring range inSearchRange; the delimeter strings %are included in the result.  The inMask parameter is the same as is passed to [NSString rangeOfString:options:range:].
 "*/

- (NSRange)rangeFromString:(NSString *)inString1 toString:(NSString *)inString2
				   options:(unsigned)inMask range:(NSRange)inSearchRange
{
	NSRange result;
	NSRange stringStart = NSMakeRange(inSearchRange.location,0); // if no start string, start here
	unsigned int foundLocation = inSearchRange.location;	// if no start string, start here
	NSRange stringEnd = NSMakeRange(NSMaxRange(inSearchRange),0); // if no end string, end here
	NSRange endSearchRange;
	if (nil != inString1)
	{
		// Find the range of the list start
		stringStart = [self rangeOfString:inString1 options:inMask range:inSearchRange];
		if (NSNotFound == stringStart.location)
		{
			return stringStart;	// not found
		}
		foundLocation = NSMaxRange(stringStart);
	}
	endSearchRange = NSMakeRange( foundLocation, NSMaxRange(inSearchRange) - foundLocation );
	if (nil != inString2)
	{
		stringEnd = [self rangeOfString:inString2 options:inMask range:endSearchRange];
		if (NSNotFound == stringEnd.location)
		{
			return stringEnd;	// not found
		}
	}
	result = NSMakeRange (stringStart.location, NSMaxRange(stringEnd) - stringStart.location );
	return result;
}


/*"	Find a string between the two given strings with the default options; the delimeter strings are not included in the result.
 "*/

- (NSRange)rangeBetweenString:(NSString *)inString1 andString:(NSString *)inString2
{
	return [self rangeBetweenString:inString1 andString:inString2 options:0];
}

/*"	Find a string between the two given strings with the given options inMask; the delimeter strings are not included in the result.  The inMask parameter is the same as is passed to [NSString rangeOfString:options:range:].
 "*/

- (NSRange)rangeBetweenString:(NSString *)inString1 andString:(NSString *)inString2
					  options:(unsigned)inMask
{
	return [self rangeBetweenString:inString1 andString:inString2
                            options:inMask
                              range:NSMakeRange(0,[self length])];
}

/*"	Find a string between the two given strings with the given options inMask and the given substring range inSearchRange; the delimeter strings are not included in the result.  The inMask parameter is the same as is passed to [NSString rangeOfString:options:range:].
 "*/

- (NSRange)rangeBetweenString:(NSString *)inString1 andString:(NSString *)inString2
					  options:(unsigned)inMask range:(NSRange)inSearchRange
{
	NSRange result;
	unsigned int foundLocation = inSearchRange.location;	// if no start string, start here
	NSRange stringEnd = NSMakeRange(NSMaxRange(inSearchRange),0); // if no end string, end here
	NSRange endSearchRange;
	if (nil != inString1)
	{
		// Find the range of the list start
		NSRange stringStart = [self rangeOfString:inString1 options:inMask range:inSearchRange];
		if (NSNotFound == stringStart.location)
		{
			return stringStart;	// not found
		}
		foundLocation = NSMaxRange(stringStart);
	}
	endSearchRange = NSMakeRange( foundLocation, NSMaxRange(inSearchRange) - foundLocation );
	if (nil != inString2)
	{
		stringEnd = [self rangeOfString:inString2 options:inMask range:endSearchRange];
		if (NSNotFound == stringEnd.location)
		{
			return stringEnd;	// not found
		}
	}
	result = NSMakeRange( foundLocation, stringEnd.location - foundLocation );
	return result;
}

/*!	Remove characters in the given set from the string; return a new string.
 */
- (NSString *) stringByRemovingCharactersInSet:(NSCharacterSet *)aSet
{
	NSString *result = self;
	NSRange firstBadRange = [self rangeOfCharacterFromSet:aSet];
	if (NSNotFound != firstBadRange.location)
	{
		// Slight inefficiency: we already scanned to find first one; we COULD make use of that!
		NSScanner *scanner = [NSScanner scannerWithString:self];
		[scanner setCharactersToBeSkipped:nil];
		NSMutableString *buffer = [NSMutableString stringWithCapacity: [self length]];
		while (![scanner isAtEnd])
		{
			NSString *beforeBadCharacters = nil;
			BOOL found = [scanner scanUpToCharactersFromSet:aSet intoString:&beforeBadCharacters];
			if (found)
			{
				[buffer appendString:beforeBadCharacters];
			}
			// Process characters that need escaping
			if (![scanner isAtEnd])
			{
				[scanner scanCharactersFromSet:aSet intoString:nil];
			}
		}
		result = buffer;
	}
	return result;
}

- (NSString *) removeWhiteSpace
{
	return [self stringByRemovingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

/*"	Take out all but the first decimal point, and turn into a floating number.
 This isn't going to do well with numbers >=10 between the decimal points
 1.0 -> 1.0
 1.1 -> 1.1
 1.1.1 -> 1.11
 1.2.3.4 -> 1.234
 but
 1.10 -> 1.1 and 1.1 -> 1.1 !
 etc.
 "*/
- (float) floatVersion
{
	float result = 0.0;
	NSMutableString *buf = [NSMutableString string];
	NSArray *comp = [self componentsSeparatedByString:@"."];
	if ([comp count] > 0)
	{
		[buf appendString:[comp objectAtIndex:0]];
		
		if ([comp count] > 1)
		{
			NSRange range = NSMakeRange(1, [comp count] - 1);
			NSArray *subComp = [comp subarrayWithRange:range];
			NSString *dec = [subComp componentsJoinedByString:@""];
			
			[buf appendString:@"."];
			[buf appendString:dec];
		}
	}
	result = [buf floatValue];
	return result;
}

/*"	General search-and-replace mechanism to convert text between the given delimeters.  Pass in a dictionary with the keys of "from" strings, and the values of what to convert them to.  If not found in the dictionary,  the text will just be removed.  If the dictionary passed in is nil, then the string between the delimeters will put in the place of the whole range; this could be used to just strip out the delimeters.
 
 Requires -[NSString rangeFromString:toString:options:range:].
 "*/

- (NSString *) replaceAllTextBetweenString:(NSString *)inString1 andString:(NSString *)inString2
							fromDictionary:(NSDictionary *)inDict
								   options:(unsigned)inMask range:(NSRange)inSearchRange
{
	NSRange range = inSearchRange;	// We'll increment this
	int startLength = [inString1 length];
	int delimLength = startLength + [inString2 length];
	NSMutableString *buf = [NSMutableString string];
	
	NSRange beforeSearchRange = NSMakeRange(0,inSearchRange.location);
	[buf appendString:[self substringWithRange:beforeSearchRange]];
	
	// Now loop through; looking.
	while (range.length != 0)
	{
		NSRange foundRange = [self rangeBetweenString:inString1 andString:inString2 options:inMask range:range];	// CHANGED FROM SANDVOX
		if (foundRange.location != NSNotFound)
		{
			// First, append what was the search range and the found range -- before match -- to output
			{
				NSRange beforeRange = NSMakeRange(range.location, foundRange.location - range.location);
				NSString *before = [self substringWithRange:beforeRange];
				[buf appendString:before];
			}
			// Now, figure out what was between those two strings
			{
				// OLD -- FOR RANGEFFROMSTRING NSRange betweenRange = NSMakeRange(foundRange.location + startLength, foundRange.length - delimLength);
				NSString *between = [self substringWithRange:foundRange];
				if (nil != inDict)
				{
					between = [inDict objectForKey:between];	// replace string
				}
				// Now append the between value if not nil
				if (nil != between)
				{
					[buf appendString:[between description]];
				}
			}
			// Now, update things and move on.
			range.length = NSMaxRange(range) - NSMaxRange(foundRange);
			range.location = NSMaxRange(foundRange);
		}
		else
		{
			NSString *after = [self substringWithRange:range];
			[buf appendString:after];
			// Now, update to be past the range, to finish up.
			range.location = NSMaxRange(range);
			range.length = 0;
		}
	}
	// Finally, append stuff after the search range
	{
		NSRange afterSearchRange = NSMakeRange(range.location, [self length] - range.location);
		[buf appendString:[self substringWithRange:afterSearchRange]];
	}
	return buf;
}


/*"	Replace between the two given strings with the given options inMask; the delimeter strings are not included in the result.  The inMask parameter is the same as is passed to [NSString rangeOfString:options:range:].
 "*/

- (NSString *) replaceAllTextBetweenString:(NSString *)inString1 andString:(NSString *)inString2
							fromDictionary:(NSDictionary *)inDict
								   options:(unsigned)inMask

{
	return [self replaceAllTextBetweenString:inString1 andString:inString2
							  fromDictionary:inDict 
									 options:inMask
									   range:NSMakeRange(0,[self length])];
}

/*"	Replace between the two given strings with the default options; the delimeter strings are not included in the result.
 "*/

- (NSString *) replaceAllTextBetweenString:(NSString *)inString1 andString:(NSString *)inString2
							fromDictionary:(NSDictionary *)inDict
{
	return [self replaceAllTextBetweenString:inString1 andString:inString2 fromDictionary:inDict options:0];
}


@end
