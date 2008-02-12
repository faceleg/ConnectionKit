//
//  NSString+KTExtensions.m
//  KTComponents
//
//  Copyright (c) 2004-2005 Biophony LLC. All rights reserved.
//

#import "NSString+KTExtensions.h"
#import "NSData+KTExtensions.h"
#import "NSCharacterSet+KTExtensions.h"
#import "NSString-Utilities.h"
#import "KT.h"

@implementation NSString ( KTExtensions )


- (NSString *)legalizeURLNameWithFallbackID:(NSString *)idString
{
	// Convert to lowercase, spaces as _, removing everything else
	NSString *legalized = self;
	
	// lossy convert to data and back to a string
	
	// special chars to be smarter than Apple
	legalized = [legalized stringByReplacing:[NSString stringWithUnichar:0x00df] with:@"ss"]; // German double-s
	
	// We are getting strange errors
	// *** -[NSCFString dataUsingEncoding:allowLossyConversion:]: didn't convert all characters
	// Pull out all illegal characters but keep in all alpha, including non-ascii.
	legalized = [legalized stringByRemovingCharactersInSet:[NSCharacterSet prescreenIllegalCharacterSet]];
	
	// Possible alternative:  CFStringGetBytes  ?
	
	NSData *asciiData = [legalized dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
	legalized = [[[NSString alloc] initWithData:asciiData encoding:NSASCIIStringEncoding] autorelease];
	
	legalized = [legalized lowercaseString];
	legalized = [legalized stringByReplacing:@" " with:@"_"];
	
	legalized = [legalized stringByRemovingCharactersInSet:[[NSCharacterSet legalPageTitleCharacterSet] invertedSet]];
	
	legalized = [legalized condenseMultipleCharactersFromSet:
				[NSCharacterSet characterSetWithCharactersInString:@"_"] into:'_'];
	
	// strip off any leading dashes to deal with Yahoo FTP requirements
	while ( [legalized hasPrefix:@"-"] )
	{
		legalized = [legalized substringFromIndex:1];
	}
	
	if ([legalized length] > 27)
	{
		legalized = [legalized substringToIndex:27];	// keep name + ".html" in 32 chars
	}
	
	if ([legalized length] <= 2)		// is there nothing or little we can use?
	{
		if ([legalized isEqualToString:@""])
		{
			legalized = [NSString stringWithFormat:@"id%@", idString];
		}
		else
		{
			legalized = [legalized stringByAppendingString:idString];
		}
	}
	return legalized;
}

- (NSString *)legalizeFileNameWithFallbackID:(NSString *)idString
{
	NSString *legalized = [self legalizeURLNameWithFallbackID:idString];
	NSString *result = [legalized lowercaseString];
	return result;
}

// see http://developer.apple.com/qa/qa2001/qa1235.html
// We should normalize the HTML we publish.
// See https://karelia.fogbugz.com/default.asp?8219

- (NSString *)normalizeUnicode
{
	CFMutableStringRef mutString = (CFMutableStringRef)[NSMutableString stringWithString:self];
	CFStringNormalize(mutString, kCFStringNormalizationFormC);
	return [NSString stringWithString:(NSString *)mutString];
}

/*!	Simple factory method equivalent to -initWithData:encoding:
 */
+ (NSString *)stringWithData:(NSData *)data encoding:(NSStringEncoding)encoding
{
	return [[[self alloc] initWithData: data encoding: encoding] autorelease];
}

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

+ (NSString *)charsetFromEncoding:(NSStringEncoding)anEncoding
{
	CFStringEncoding encoding = CFStringConvertNSStringEncodingToEncoding(anEncoding);
	CFStringRef result = CFStringConvertEncodingToIANACharSetName(encoding);
	return (NSString *)result;
}

+ (NSString *)GUIDString
{
    CFUUIDRef uuid = CFUUIDCreate(NULL);
    NSString *uString = (NSString *)CFUUIDCreateString(NULL, uuid);
    CFRelease(uuid);
    
    return [uString autorelease];
}

/*!	Returns a shorter version of a GUID string.  These no longer have the ethernet address in there,
	so to be truly unique, let's 
*/
+ (NSString *)shortGUIDString
{
    NSString *idString = [self GUIDString];
	NSMutableString *shortIDString;
	
	// Remove the piece after the last "-" : this is the ethernet address, which we don't need
	NSRange lastDashRange = [idString rangeOfString:@"-" options:NSBackwardsSearch];
	if (NSNotFound != lastDashRange.location)
	{
		shortIDString = [NSMutableString stringWithString:[idString substringToIndex:lastDashRange.location]];
	}
	else
	{
		shortIDString = [NSMutableString stringWithString:idString];
	}
	[shortIDString replaceOccurrencesOfString:@"-" withString:@"" options:0 range:NSMakeRange(0, [shortIDString length])];

    return shortIDString;
}

- (NSString *)stringByAppendingDirectoryTerminator
{
    //    if ( ![[self lastPathComponent] isEqualToString:@"/"] )
    if ( ![self hasSuffix:@"/"] )
    {
        return [self stringByAppendingString:@"/"];
    }
    else
    {
        return self;
    }    
}

/*! turns path/to/thing into path > to > thing */
- (NSString *)stringBySubstitutingRightArrowForPathSeparator
{
	NSString *result = nil;

	static const unichar PATH_SEPARATOR[] = {' ', 0x25B8, ' '};
	NSString *separator = [[NSString alloc] initWithCharacters:PATH_SEPARATOR length:3];
	
	NSArray *components = [self pathComponents];
	int count = [components count];
	
	NSMutableString *path = [NSMutableString stringWithCapacity:count];
	int i;
	for ( i=0; i<count; i++ )
	{
		NSString *component = [components objectAtIndex:i];
		if ( nil != component )
		{
			[path appendString:component];
		}
		
		if ( i < (count -1) )
		{
			[path appendString:separator];
		}
	}
	
	[separator release];
	
	if ( [path length] > 0 )
	{
		result = [NSString stringWithString:path];
	}
	
	return result;	
}

/*	Turns a given path into a directory path suitable for HTML.
 *
 *		e.g.	/photo_album	->	/photo_album/
 *
 *	If you pass in an empty string or @"/" nothing is done though.
 */
- (NSString *)HTMLdirectoryPath
{
	NSString *result = self;
	
	if (![self isEqualToString:@""] && ![self isEqualToString:@"/"])
	{
		result = [self stringByAppendingString:@"/"];
	}
	
	return result;
}

/*!	Figures out relative path, from otherPath to this
*/
- (NSString *)pathRelativeTo:(NSString *)otherPath
{
	// SANDVOX ONLY -- if we have a special page ID, then don't try to make relative
	if (NSNotFound != [otherPath rangeOfString:kKTPageIDDesignator].location)
	{
		return self;
	}	
	
	// General Purpose
	
	NSString *commonPrefix = [self commonPrefixWithString:otherPath options:NSLiteralSearch];
	// Make sure common prefix ends with a / ... if not, back up to the previous /
	if ([commonPrefix isEqualToString:@""])
	{
		return self;
	}
	if (![commonPrefix hasSuffix:@"/"])
	{
		NSRange whereSlash = [commonPrefix rangeOfString:@"/" options:NSLiteralSearch|NSBackwardsSearch];
		if (NSNotFound == whereSlash.location)
		{
			return self;	// nothing in common, return
		}

		// Fix commonPrefix so it ends in /
		commonPrefix = [commonPrefix substringToIndex:NSMaxRange(whereSlash)];
	}

	NSString *myDifferingPath = [self substringFromIndex:[commonPrefix length]];
	NSString *otherDifferingPath = [otherPath substringFromIndex:[commonPrefix length]];
	
	NSMutableString *buf = [NSMutableString string];
	unsigned int i;
	
	// generate hops up from other to the common place
	NSArray *hopsUpArray = [otherDifferingPath pathComponents];
	unsigned int hopsUp = MAX(0,(int)[hopsUpArray count] - 1);
	for (i = 0 ; i < hopsUp ; i++ )
	{
		[buf appendString:@"../"];
	}
	
	// the rest is the relative path to me
	[buf appendString:myDifferingPath];
	
	if ([buf isEqualToString:@""])	
	{
		if ([self hasSuffix:@"/"])
		{
			[buf appendString:@"./"];	// if our relative link is to the top, then replace with ./
		}
		else	// link to yourself; give us just the file name
		{
			[buf appendString:[self lastPathComponent]];
		}
	}
	NSString *result = [NSString stringWithString:buf];
	return result;
}


//- (NSString *)pathRelativeToRoot
//{
//    // remove everything up to, but not including, Source
//    // so /Users/ttalbot/Sites/BigSite.site/Contents/Source/whatever becomes Source/whatever
//    NSMutableArray *components = [NSMutableArray arrayWithArray:[self pathComponents]];
//    NSEnumerator *componentsEnumerator = [components objectEnumerator];
//    NSString *component;
//    
//    while ( component = [componentsEnumerator nextObject] ) {
//        if ( ![component isEqualToString:@"Source"] ) {
//            [components removeObject:component];
//        }
//        else {
//            break;
//        }
//    }
//    return [NSString pathWithComponents:components];
//}

- (NSArray *)componentsSeparatedByWhitespace
{
	NSMutableArray *result = [NSMutableArray array];

	NSCharacterSet *white = [NSCharacterSet fullWhitespaceAndNewlineCharacterSet];
	NSScanner *scanner = [NSScanner scannerWithString:self];
	while (![scanner isAtEnd])
	{
		NSString *word;
		// Scan any prior whitespace characters
		[scanner scanCharactersFromSet:white intoString:nil];
		// Scan in the word
		if ([scanner scanUpToCharactersFromSet:white intoString:&word])
		{
			[result addObject:word];
		}
	}
	return [NSArray arrayWithArray:result];
}

- (NSArray *)componentsSeparatedByCommas
{
	NSMutableArray *result = [NSMutableArray array];
	
	NSScanner *scanner = [NSScanner scannerWithString:self];
	NSCharacterSet *white = [NSCharacterSet fullWhitespaceAndNewlineCharacterSet];
	[scanner setCharactersToBeSkipped:white];
	while (![scanner isAtEnd])
	{
		NSString *item;
		// Scan in the word
		if ([scanner scanUpToString:@"," intoString:&item])
		{
			[result addObject:item];
		}
		[scanner scanString:@"," intoString:nil];
	}
	return [NSArray arrayWithArray:result];
}

- (ComparisonType) parseComparisonintoLeft:(NSString **)outLeft right:(NSString **)outRight
{
	// This is candidates to scan for.  Start with the longer ones to match the biggest possible token
	// If only one term and no token, then we're checking for non-emptiness.
	
	NSArray *comparisonTokens = [NSArray arrayWithObjects:
		@"==", @"!=", @"<>", @"><", @">=", @"=>", @"<=", @"=<", @"<", @">", @"=", @"||", @"&&", @"|editing", nil];
	ComparisonType comparisonInts[] = { kCompareEquals, kCompareNotEquals, kCompareNotEquals,
		kCompareNotEquals, kCompareMoreEquals, kCompareMoreEquals, kCompareLessEquals,
		kCompareLessEquals, kCompareLess, kCompareMore, kCompareEquals, kCompareOr, kCompareAnd,
		kCompareNotEmptyOrEditing };
	
	// Start looking for each token.  When we find one, then we can parse out the pieces.
	NSEnumerator *theEnum = [comparisonTokens objectEnumerator];
	NSString *aToken;
	int i = 0;

	while (nil != (aToken = [theEnum nextObject]) )
	{
		NSRange tokenRange = [self rangeOfString:aToken];
		if (NSNotFound != tokenRange.location)
		{
			if (nil != outLeft)
			{
				*outLeft = [[self substringToIndex:tokenRange.location] trim];
			}
			if (nil != outRight)
			{
				*outRight = [[self substringFromIndex:tokenRange.location + tokenRange.length] trim];
			}
			return comparisonInts[i];
		}
		i++;
	}
	// not found; assume it's a single-argument check for non-emptiness.
	// Future enhancements could check validity, make sure it's a valid keypath, etc, and return
	// unknownComparison if invalid.
	if (nil != outLeft)
	{
		*outLeft = [self trim];
	}
	if (nil != outRight)
	{
		*outRight = nil;
	}
	return kCompareNotEmpty;
}

/*"	Remove HTML tags to turn a fragment of HTML into a piece of plain text.  All characters between < and > are removed.
Escape sequences such as &amp; are converted into their character equivalents.
"*/


- (NSString *) flattenHTML
{
	NSString *result = nil;

	//
	//  NOT USING THIS -- FOR SOME REASON I GET SOME XML PARSER CRASHES, SO LET'S NOT USE IT.
	//
//	static NSCharacterSet *sHTMLSet = nil;
//	if (nil == sHTMLSet)
//	{
//		sHTMLSet = [[NSCharacterSet characterSetWithCharactersInString:@"<>&"] retain];
//	}
//	if (NSNotFound != [self rangeOfCharacterFromSet:sHTMLSet].location)	// don't bother if no HTML markup
//	{
//		NSError *theError = nil;	// ignore these warnings galore; it wants a FULL html page
//		NSXMLDocument *xmlDoc = [[[NSXMLDocument alloc] initWithXMLString:self options:NSXMLDocumentTidyHTML error:&theError] autorelease];
//		if (xmlDoc)
//		{
//// This doesn't work; it yields a full XHTML dump. Reported to apple.
////			NSData *xmlData = [xmlDoc XMLDataWithOptions:NSXMLDocumentTextKind];
////			result = [[[NSString alloc] initWithData:xmlData encoding:NSUTF8StringEncoding] autorelease];
//
//			// Technique adapted from here: http://sugarmaplesoftware.com/25/strip-html-tags/#comment-74
//			NSString *theXSLTString = @"<?xml version='1.0' encoding='utf-8'?>\
//<xsl:stylesheet version='1.0' xmlns:xsl='http://www.w3.org/1999/XSL/Transform' xmlns:xhtml='http://www.w3.org/1999/xhtml'>\
//<xsl:output method='text'/>\
//<xsl:template match='xhtml:head'></xsl:template>\
//<xsl:template match='xhtml:script'></xsl:template>\
//</xsl:stylesheet>";
//			
//			// Depending on intended output, the method returns an NSXMLDocument object or an NSData data containing transformed XML or HTML markup. If the message is supposed to create plain text or RTF, then an NSData object is returned, otherwise an XML document object. The method returns nil if XSLT processing did not succeed.
//			
//			// Seems to return an XMLDoc of <?xml version="1.0"?> when just "<br />" is passed in!
//			NSData *theData = [xmlDoc objectByApplyingXSLTString:theXSLTString arguments:NULL error:&theError];
//			if ([theData isKindOfClass:[NSData class]])
//			{
//				result = [[[NSString alloc] initWithData:theData encoding:NSUTF8StringEncoding] autorelease];
//			}
//		}
//	}
//	if (nil == result)
	{
		// old brute-force way
		result = [self replaceAllTextBetweenString:@"<" andString:@">" fromDictionary:[NSDictionary dictionary]];
		result = [result unescapedEntities];
		result = [result condenseWhiteSpace];
	}
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
		result = [NSString stringWithString:buffer];
	}
	return result;
}

/*! Remove all characters not in the set. Return a new string
*/
- (NSString *)stringByRemovingCharactersNotInSet:(NSCharacterSet *)validCharacters
{
	NSMutableString *intermediateResult = [[NSMutableString alloc] initWithCapacity: [self length]];
	NSScanner *scanner = [[NSScanner alloc] initWithString: self];
	
	while (![scanner isAtEnd])
	{
		[scanner scanUpToCharactersFromSet: validCharacters intoString: NULL];
		
		// If we have now reached the end of the string, exit the loop early
		if ([scanner isAtEnd])
			break;
		
		NSString *resultSubString = nil;
		[scanner scanCharactersFromSet: validCharacters intoString: &resultSubString];
		
		[intermediateResult appendString: resultSubString];
	}
	
	// Tidy up
	[scanner release];
	
	NSString *result = [NSString stringWithString: intermediateResult];
	[intermediateResult release];
	return result;
}

/*"	Convert a plain string into a new string, replacing certain characters with the equivalent percent escape sequence.
	Don't run this on a fully finished URL, because it will escape the & characters
"*/

- (NSString *)urlEncode
{
	// First encode everything except for the spaces
	NSString *result = (NSString *) CFURLCreateStringByAddingPercentEscapes(
		NULL, (CFStringRef) self, (CFStringRef)@" ", (CFStringRef)@"&+%=",		// Now we escape % and & and + and = also, since they are part of parameters too
		CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
	[result autorelease];
	
	// Now convert space to +
	result = [result stringByReplacing:@" " with:@"+"];
	return result;
}

- (NSString *)urlEncodeNoPlus		// file names don't want plusses!
{
	// First encode everything except for the spaces
	NSString *result = (NSString *) CFURLCreateStringByAddingPercentEscapes(
		NULL, (CFStringRef) self, (CFStringRef)@"", (CFStringRef)@"&+%=",		// Now we escape % and & and + and = also, since they are part of parameters too
		CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
	[result autorelease];
	return result;
}


/*!	Decode a URL string, taking out the + and %XX stuff
*/

- (NSString *)urlDecode
{
	NSString *result = (NSString *) CFURLCreateStringByReplacingPercentEscapes(
		NULL, (CFStringRef) self, CFSTR(""));
	[result autorelease];
	result = [result stringByReplacing:@"+" with:@" "];	// fix + signs too!
	/// defend against nil
	if (nil == result) result = @"";
	return result;
}

/*!	Decode the query section of a URL, returning a dictionary of its values
*/
- (NSDictionary *)queryParameters
{
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	NSArray *keyValues = [self componentsSeparatedByString:@"&"];
	NSEnumerator *theEnum = [keyValues objectEnumerator];
	NSString *keyValuePair;
	
	while (nil != (keyValuePair = [theEnum nextObject]) )
	{
		NSRange whereEquals = [keyValuePair rangeOfString:@"="];
		if (NSNotFound != whereEquals.location)
		{
			NSString *key = [keyValuePair substringToIndex:whereEquals.location];
			NSString *value = [[keyValuePair substringFromIndex:whereEquals.location+1] urlDecode];
			[dict setValue:value forKey:key];
		}
	}
	return [NSDictionary dictionaryWithDictionary:dict];
}


/*"	Fix a URL-encoded string that may have some characters that makes NSURL barf.
It basicaly re-encodes the string, but ignores escape characters + and %, and also #.
Example bad characters:  smart quotes.  If you try to create NSURL URLWithString: and your string
has smart quotes, the NSURL is nil!
"*/
- (NSString *)encodeLegally
{
	NSString *result = (NSString *) CFURLCreateStringByAddingPercentEscapes(
		NULL, (CFStringRef) self, (CFStringRef) @"%+#", NULL,
		CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
	return [result autorelease];
}


+ (NSString *)stringWithUnichar:(unichar) inChar
{
	NSString *result = [NSString stringWithCharacters:&inChar length:1];
	return result;
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


/*
	Return the range of a substring, searching between a starting and ending delimeters
	Original Source: <http://cocoa.karelia.com/Foundation_Categories/NSString/Return_the_range_of.m>
	(See copyright notice at <http://cocoa.karelia.com>)
     */

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
		NSRange foundRange = [self rangeFromString:inString1 toString:inString2 options:inMask range:range];
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
				NSRange betweenRange = NSMakeRange(foundRange.location + startLength, foundRange.length - delimLength);
				NSString *between = [self substringWithRange:betweenRange];
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
	return [NSString stringWithString:buf];
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


/*!	Escape & < > " ... does NOT escape anything else.  Need to deal with character set in subsequent pass.
	Escaping " so that strings work within HTML tags
*/
- (NSString *)escapedEntities;
{
	NSCharacterSet *escapedSet = [NSCharacterSet characterSetWithCharactersInString:@"&<>\""];

	NSMutableString *result = [NSMutableString stringWithCapacity: [self length]];
	NSScanner *scanner = [NSScanner scannerWithString:self];
	[scanner setCharactersToBeSkipped:nil];
	while (![scanner isAtEnd])
	{
		NSString *unescaped = nil;
		BOOL found = [scanner scanUpToCharactersFromSet:escapedSet intoString:&unescaped];
		if (found)
		{
			[result appendString:unescaped];
		}
		// Process characters that need escaping
		if (![scanner isAtEnd])
		{
			NSString *toEscape = nil;
			[scanner scanCharactersFromSet:escapedSet intoString:&toEscape];
			int anIndex, length = [toEscape length];
			for( anIndex = 0; anIndex < length; anIndex++ )
			{
				unichar ch = [toEscape characterAtIndex:anIndex];
				switch (ch)
				{
					case '&':	[result appendString:@"&amp;"];		break;
					case '<':	[result appendString:@"&lt;"];		break;
					case '>':	[result appendString:@"&gt;"];		break;
					case '"':	[result appendString:@"&quot;"];	break;
				}
			}
		}
	}	
	return result;
}

- (NSString *)escapeCharactersOutOfCharset:(NSString *)aCharset;
{
	NSStringEncoding encoding = [aCharset encodingFromCharset];
	return [self escapeCharactersOutOfEncoding:encoding];
}

// escape whatever isn't covered by the character set.  NBSP is special -- for HTML, we usually want
// to encode it, for XML, no.

- (NSString *)escapeCharactersOutOfEncoding:(NSStringEncoding)anEncoding;
{
	
    if ( ! (	anEncoding == NSASCIIStringEncoding
			||	anEncoding == NSUTF8StringEncoding
			||	anEncoding == NSISOLatin1StringEncoding
			||	anEncoding == NSUnicodeStringEncoding ) )
    {
        [NSException raise:NSInvalidArgumentException format:@"Unsupported character encoding"];
    }
	
	// first make the set of legal characters
	NSMutableCharacterSet *legalSet = [[[NSMutableCharacterSet alloc] init] autorelease];
	
	switch(anEncoding)
	{
		case NSUTF8StringEncoding:
		case NSUnicodeStringEncoding:	// Everything above 0x100 too..  Not sure about > 32 bit codes, though.
			[legalSet addCharactersInRange:NSMakeRange(0,0x100)];
			[legalSet invert];		// easier to create items we don't want, then invert
			// FALL THROUGH

		case NSISOLatin1StringEncoding:	// 0xA0 through 0xFF
			[legalSet addCharactersInRange:NSMakeRange(0xA0, 0x100 - 0xA0)];
			// FALL THROUGH
			
		case NSASCIIStringEncoding:		// only 0x20 through 0x7F
			[legalSet addCharactersInRange:NSMakeRange(0x20, 0x80 - 0x20)];
			break;
	}
	
	// Allow white space to pass through normally
	[legalSet addCharactersInString:@"\r\n\t"];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults boolForKey:@"EscapeNBSP"])
	{
		// Take out special characters which we ALWAYS want to escape
		[legalSet removeCharactersInRange:NSMakeRange(160,1)];		// nbsp ... since they are hard to spot!
	}
	
	// From now on we're working with the inverse -- all illegal characters
	NSCharacterSet *escapedSet = [legalSet invertedSet];
	
	NSMutableString *result = [NSMutableString stringWithCapacity: [self length]];
	NSScanner *scanner = [NSScanner scannerWithString:self];
	[scanner setCharactersToBeSkipped:nil];
	while (![scanner isAtEnd])
	{
		NSString *unescaped = nil;
		BOOL found = [scanner scanUpToCharactersFromSet:escapedSet intoString:&unescaped];
		if (found)
		{
			[result appendString:unescaped];
		}
		// Process characters that need escaping
		if (![scanner isAtEnd])
		{
			NSString *toEscape = nil;
			[scanner scanCharactersFromSet:escapedSet intoString:&toEscape];
			int anIndex, length = [toEscape length];
			for( anIndex = 0; anIndex < length; anIndex++ )
			{
				unichar ch = [toEscape characterAtIndex:anIndex];
				switch (ch)
				{
					// If we encounter a special character with a symbolic entity, use that
					case 160:	[result appendString:@"&nbsp;"];	break;
					case 169:	[result appendString:@"&copy;"];	break;
					case 174:	[result appendString:@"&reg;"];		break;
					case 8211:	[result appendString:@"&ndash;"];	break;
					case 8212:	[result appendString:@"&mdash;"];	break;
					case 8364:	[result appendString:@"&euro;"];	break;
						
					// Otherwise, use the decimal unicode value.
					default:	[result appendFormat:@"&#%d;",ch];	break;
				}
			}
		}
	}	
	return result;
}

/*!	Convert a string with entities escaped into a regular string.  This is going to be limited; it
	can't parse arbitrary HTML, but the idea is that the only string we're going to get is one that
	was set from escapedEntities.

	The way this works is just to look for each & and de-escape it.

	It would be nice to handle all possible symbolic entities ... but we don't.

	The result is a unicode string.
*/
- (NSString *)unescapedEntities
{
	static NSDictionary *sReplacements = nil;
	if (nil == sReplacements)
	{
		sReplacements = [[NSDictionary alloc] initWithObjectsAndKeys:
			[NSNumber numberWithInt:'&'], @"amp",
			[NSNumber numberWithInt:'\''], @"apos",
			[NSNumber numberWithInt:'"'], @"quot",
			[NSNumber numberWithInt:'<'], @"lt",
			[NSNumber numberWithInt:'>'], @"gt",
			[NSNumber numberWithInt:160], @"nbsp",
			[NSNumber numberWithInt:169], @"copy",
			[NSNumber numberWithInt:174], @"reg",
			[NSNumber numberWithInt:8211], @"ndash",
			[NSNumber numberWithInt:8212], @"mdash",
			[NSNumber numberWithInt:8364], @"euro",
			nil];
	}
		
	NSMutableString *result = [NSMutableString stringWithCapacity: [self length]];
	NSScanner *scanner = [NSScanner scannerWithString:self];
	[scanner setCharactersToBeSkipped:nil];
	while (![scanner isAtEnd])
	{
		NSString *unescaped = nil;
		BOOL foundBefore = [scanner scanUpToString:@"&" intoString:&unescaped];
		if (foundBefore)
		{
			[result appendString:unescaped];
		}
		if (![scanner isAtEnd])
		{
			BOOL foundAmp = [scanner scanString:@"&" intoString:nil];
			if (foundAmp)
			{
				NSString *entity;
				BOOL foundSemi = [scanner scanUpToString:@";" intoString:&entity];
				if (foundSemi)
				{
					[scanner scanString:@";" intoString:nil];

					unichar replacementChar = '?';
					
					if ([entity hasPrefix:@"#"])
					{
						// Convert after the # into a decimal number
						replacementChar = [[entity substringFromIndex:1] intValue];
					}
					else
					{
						NSNumber *replacementNumber = [sReplacements objectForKey:entity];
						if (nil != replacementNumber)
						{
							replacementChar = [replacementNumber intValue];
						}
					}
					[result appendFormat:@"%C", replacementChar];
				}
			}
		}
	}	
	return result;
}


/*"	Split a string into lines separated by any of the various newline characters.  Equivalent to componentsSeparatedByString:@"\n" but it works with the different line separators: \r, \n, \r\n, 0x2028, 0x2029 "*/

- (NSArray *)componentsSeparatedByLineSeparators
{
	NSMutableArray *result	= [NSMutableArray array];
	NSRange range = NSMakeRange(0,0);
	unsigned start, end;
	unsigned contentsEnd = 0;
	
	while (contentsEnd < [self length])
	{
		[self getLineStart:&start end:&end contentsEnd:&contentsEnd forRange:range];
		[result addObject:[self substringWithRange:NSMakeRange(start,contentsEnd-start)]];
		range.location = end;
		range.length = 0;
	}
	return result;
}


/*"	Just like the above, but this one retains the newline characters (standardizing as \n)
and gobbles up multiples, so Hi\nThere\n\nDan\n becomes "Hi\n", "There\n\n", "Dan\n"
"*/

- (NSArray *)componentsSeparatedByLineSeparatorsWithNewlines
{
	NSMutableArray *result	= [NSMutableArray array];
	NSRange range = NSMakeRange(0,0);
	unsigned start = 0, end = 0;
	unsigned contentsEnd = 0;
	NSString *lastString = nil;
	
	while (end < [self length])
	{
		[self getLineStart:&start end:&end contentsEnd:&contentsEnd forRange:range];
		if (start == contentsEnd && nil != lastString)
		{
			// Empty line, need to append another newline to last entry
			lastString = [NSString stringWithFormat:@"%@\n",lastString];
			[result replaceObjectAtIndex:([result count]-1) withObject:lastString];
		}
		else	// a valid, add it and any line separator to array
		{
			lastString = [self substringWithRange:NSMakeRange(start,end-start)];
			[result addObject:lastString];
		}
		range.location = end;
		range.length = 0;
	}
	return result;
}


- (NSString *)breakBetweenLines;
{
	NSArray *lines = [self componentsSeparatedByLineSeparators];
	NSString *result = [lines componentsJoinedByString:@"<br />"];
	return result;
}


/*!	Parse the HTML string and return an attributed string, with a base of system font black
*/
-(NSAttributedString *)parseHTML
{
	NSString *htmlToParse = self;
	NSData *theData = [htmlToParse dataUsingEncoding:NSUnicodeStringEncoding allowLossyConversion:YES];
	
	NSDictionary *encodingDict = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt:NSUnicodeStringEncoding], @"CharacterEncoding", nil];
	NSMutableAttributedString *result = [[[NSMutableAttributedString alloc] initWithHTML:theData
																   options:encodingDict
														documentAttributes:nil] autorelease];
	
	[result setAttributes:[NSDictionary dictionaryWithObjectsAndKeys: 
		[NSFont systemFontOfSize:[NSFont systemFontSize]], NSFontAttributeName,
		[NSColor blackColor], NSForegroundColorAttributeName,
		nil] range:NSMakeRange(0,[result length])];
	return result;
}

/*!	Trim, and only include the first line.  Useful for cleaning up single-line inputs to make sure no CRs inserted there.
*/
- (NSString *) trimFirstLine
{
	NSString *result = self;	
	NSCharacterSet *newlines = [NSCharacterSet fullNewlineCharacterSet];
	NSScanner *scanner = [NSScanner scannerWithString:self];
	while (![scanner isAtEnd])
	{
		NSString *line;
		// Scan in the word
		if ([scanner scanUpToCharactersFromSet:newlines intoString:&line])
		{
			result = line;
			break;
		}
	}
	return [result trim];
}

/*!	Trims all white space and newlines from a string.
*/
- (NSString *) trim
{
	return [self stringByTrimmingCharactersInSet:[NSCharacterSet fullWhitespaceAndNewlineCharacterSet]];
}

/*"	Remove all white space from a string.
"*/

- (NSString *) removeWhiteSpace
{
	return [self stringByRemovingCharactersInSet:[NSCharacterSet fullWhitespaceAndNewlineCharacterSet]];
}

/*"	Return a string where runs of multiple characters from given set are condensed to single
	given character.  Trim off any leading/trailing chars too.
"*/

- (NSString *) condenseWhiteSpace	// remove runs of spaces, newlines, etc.
									// replacing with a single space
{
	return [self condenseMultipleCharactersFromSet:[NSCharacterSet fullWhitespaceAndNewlineCharacterSet] into:' '];
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

/*"	Return a string where runs of multiple white space characters (space, tab, all types of newline, return, forced space, and Unicode U+FFFC, Object replacement character) are condensed down to a single one of the SAME character.
"*/

- (NSString *) crunchWhiteSpace	// remove runs of spaces, newlines, etc.
{
	NSString *result = self;
	if (![self isEqualToString:@""])
	{
		NSCharacterSet *whitespace = [NSCharacterSet fullWhitespaceAndNewlineCharacterSet];
		// Note: we don't use whitespaceAndNewlineCharacterSet 'cause that is still missing some!
		unsigned len = [self length];
		unichar *buffer = malloc(len * sizeof(unichar));
		unsigned i;
		unsigned j = 0;
		BOOL wasWhiteSpace = NO;		// initialize to false; allowing first item to be processed normally
		for ( i = 0 ; i < len ; i++ )
		{
			unichar c = [self characterAtIndex:i];
			if ([whitespace characterIsMember:c])
			{
				if (!wasWhiteSpace)
				{
					wasWhiteSpace = YES;	// don't allow multiple in a row
					buffer[j++] = c;		// put that character into the buffer
				}
				// ignore if the last one was whitespace
			}
			else
			{
				wasWhiteSpace = NO;
				buffer[j++] = c;
			}
		}
		result = [[[NSString alloc] initWithCharacters:buffer length:j] autorelease];
		free(buffer);
	}
	
	return result;
}


- (NSString *)firstLetterCapitalizedString
{
	if ( [self length] == 1 )
	{
		return [self capitalizedString];
	}
	else
	{
		NSString *firstLetter = [[self substringToIndex:1] capitalizedString];
		NSString *otherLetters = [self substringFromIndex:1];
		return [NSString stringWithFormat:@"%@%@", firstLetter, otherLetters];	
	}
}

- (BOOL)isEmptyString
{
	return [self isEqualToString:@""];
}

- (BOOL)isValidEmailAddress
{
    // for now, just validate that syntactically it contains an @
    // we can refine this over time
    NSRange range = [self rangeOfString:@"@"];
    return (range.location != NSNotFound);
}

- (NSString *)stringWithValidURLScheme
{
	NSURL *URL = [NSURL URLWithString:[self encodeLegally]];
	NSString *scheme = [URL scheme];	// should return nil if none, or some token like 'http'
	
	// this is probably a really naive check
	if ( (nil == scheme) && ![self hasPrefix:@"/"] )
	{
        // if it looks like an email address, use mailto:
        if ( [self isValidEmailAddress] )
        {
            return [NSString stringWithFormat:@"mailto:%@", self];
        }
        else
        {
            return [NSString stringWithFormat:@"http://%@", self];
        }
	}
	else
	{
		return self;
	}
}

- (NSString *)rot13
{
	int i;
	int length = [self length];
	unichar *buffer = malloc(length * 8);	// plenty of space, not sure if 2 bytes per char is enough if composed characters! 
	[self getCharacters:buffer];
	
	for ( i = 0 ; i < length ; i++ )
	{
		unichar oneChar = buffer[i];
		unichar cap = oneChar & 32;
		oneChar &= ~cap;
		oneChar = ((oneChar >= 'A') && (oneChar <= 'Z') ? ((oneChar - 'A' + 13) % 26 + 'A') : oneChar) | cap;
		buffer[i] = oneChar;
	}
	NSString *result = [NSString stringWithCharacters:buffer length:length];
	buffer[0]='\0';	// empty out just to make sure we're done with it
	free(buffer);	// done with buffer; we've copied them out
	return result;
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

- (NSString *)removeMultipleNewlines
{
	NSMutableString *buf = [NSMutableString stringWithCapacity:[self length]];
	NSRange range = NSMakeRange(0,0);
	unsigned start, end;
	unsigned contentsEnd = 0;
	NSCharacterSet *whitespace = [NSCharacterSet whitespaceCharacterSet];
	
	while (contentsEnd < [self length])
	{
		[self getLineStart:&start end:&end contentsEnd:&contentsEnd forRange:range];
		
		NSString *line = [self substringWithRange:NSMakeRange(start,contentsEnd-start)];
		while (contentsEnd >= start
			   && contentsEnd != 0	// don't let get below zero
			   && [whitespace characterIsMember:[self characterAtIndex:contentsEnd-1]])
		{
			contentsEnd--;
		}
		
		line = [self substringWithRange:NSMakeRange(start,contentsEnd-start)];
		if (![line isEqualToString:@""])
		{
			[buf appendString:line];
			[buf appendString:@"\n"];
			
		}
		range.location = end;
		range.length = 0;
	}
	return [NSString stringWithString:buf];
}

//- (int)calculateStringChecksum:(NSString *)aWord :(int)aPrime
- (unsigned)checksum:(unsigned)aPrime
{
	int len = [self length];
	len = MIN(len, 12);			// Don't check past 12th character, only 12 will fit into 64 bits
	NSString *lowerWord = [self lowercaseString];
	long long total = 0;
	int i;
	for ( i = 0 ; i < len ; i++ )
	{
		unichar theChar = [lowerWord characterAtIndex:i] - 'a';
		total *= 26;
		total += theChar;		// basically make it like a 5-bit number
	}
	return total % aPrime;
}


#pragma mark UTIs

//  convert from UTI

+ (NSString *)filenameExtensionForUTI:(NSString *)aUTI
{
	return [(NSString *)UTTypeCopyPreferredTagWithClass(
													   (CFStringRef)aUTI,
													   kUTTagClassFilenameExtension
													   ) autorelease];
}

+ (NSString *)MIMETypeForUTI:(NSString *)aUTI
{
	return [(NSString *)UTTypeCopyPreferredTagWithClass(
													   (CFStringRef)aUTI,
													   kUTTagClassMIMEType
													   ) autorelease];
}

+ (NSString *)pboardTypeForUTI:(NSString *)aUTI
{
	return [(NSString *)UTTypeCopyPreferredTagWithClass(
													   (CFStringRef)aUTI,
													   kUTTagClassNSPboardType
													   ) autorelease];
}

+ (NSString *)fileTypeForUTI:(NSString *)aUTI
{
	return [(NSString *)UTTypeCopyPreferredTagWithClass(
													   (CFStringRef)aUTI,
													   kUTTagClassOSType
													   ) autorelease];
}

+ (OSType)OSTypeForUTI:(NSString *)aUTI
{
	return UTGetOSTypeFromString((CFStringRef)[self fileTypeForUTI:aUTI]);
}

//  convert to UTI

+ (NSString *)UTIForFileAtPath:(NSString *)anAbsolutePath
{
	NSString *result = nil;
	
	// check extension first
	NSString *extension = [anAbsolutePath pathExtension];
	if ( (nil != extension) && ![extension isEqualToString:@""] )
	{
		result = [self UTIForFilenameExtension:extension];
	}
	
	// if no extension or no result, check file type
	if ( nil == result )
	{
		NSString *fileType = NSHFSTypeOfFile(anAbsolutePath);
		if (6 == [fileType length])
		{
			fileType = [fileType substringWithRange:NSMakeRange(1,4)];
		}
		result = [self UTIForFileType:fileType];
		if ([result hasPrefix:@"dyn."])
		{
			result = nil;		// reject a dynamic type if it tries that.
		}
	}
    
	if (nil == result)	// not found, figure out if it's a directory or not
	{
		NSFileManager *fm = [NSFileManager defaultManager];
		BOOL isDirectory;
        if ( [fm fileExistsAtPath:anAbsolutePath isDirectory:&isDirectory] )
		{
			result = isDirectory ? (NSString *)kUTTypeDirectory : (NSString *)kUTTypeData;
		}
	}
	
	// Will return nil if file doesn't exist.
	
	return result;
}

/*
NOTE: THESE UTI METHODS ARE SIMILAR OR IDENTICAL TO METHODS IN IMEDIABROWSER; THE CODE WILL HAVE THE
SAME LICENSING TERMS.  PLEASE BE SURE TO "SYNC" THEM UP IF ANY FIXES ARE MADE HERE.
*/


+ (NSString *)UTIForFilenameExtension:(NSString *)anExtension
{
	NSString *UTI = nil;
	
	if ([anExtension isEqualToString:@"m4v"])
	{
		// Hack, since we already have this UTI defined in the system, I don't think I can add it to the plist.
		UTI = (NSString *)kUTTypeMPEG4;
	}
	else
	{
		UTI = [(NSString *)UTTypeCreatePreferredIdentifierForTag(
																kUTTagClassFilenameExtension,
																(CFStringRef)anExtension,
																NULL
																) autorelease];
	}
		
	// If we don't find it, add an entry to the info.plist of the APP,
	// along the lines of what is documented here: 
	// http://developer.apple.com/documentation/Carbon/Conceptual/understanding_utis/understand_utis_conc/chapter_2_section_4.html
	// A good starting point for informal ones is:
	// http://www.huw.id.au/code/fileTypeIDs.html
    
	return UTI;
}

+ (NSString *)UTIForFileType:(NSString *)aFileType;

{
	return [(NSString *)UTTypeCreatePreferredIdentifierForTag(
															 kUTTagClassOSType,
															 (CFStringRef)aFileType,
															 NULL
															 ) autorelease];	
}

+ (NSString *)UTIForMIMEType:(NSString *)aMIMEType
{
	return [(NSString *)UTTypeCreatePreferredIdentifierForTag(
															 kUTTagClassMIMEType,
															 (CFStringRef)aMIMEType,
															 kUTTypeData 
															 ) autorelease];
}

+ (NSString *)UTIForPboardType:(NSString *)aPboardType
{
	return [(NSString *)UTTypeCreatePreferredIdentifierForTag(
															 kUTTagClassNSPboardType,
															 (CFStringRef)aPboardType,
															 kUTTypeData
															 ) autorelease];
}

+ (NSString *)UTIForOSType:(OSType)anOSType
{
	NSString *OSTypeAsString = (NSString *)UTCreateStringForOSType(anOSType);
	return [self UTIForFileType:OSTypeAsString];
}

+ (BOOL)UTI:(NSString *)aUTI isEqualToUTI:(NSString *)anotherUTI
{
	return UTTypeEqual (
						(CFStringRef)aUTI,
						(CFStringRef)anotherUTI
						);
}

// See list here:
// http://developer.apple.com/documentation/Carbon/Conceptual/understanding_utis/utilist/chapter_4_section_1.html

+ (BOOL) UTI:(NSString *)aUTI conformsToUTI:(NSString *)aConformsToUTI
{
	return UTTypeConformsTo((CFStringRef)aUTI, (CFStringRef)aConformsToUTI);
}

@end

