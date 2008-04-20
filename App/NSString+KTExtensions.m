//
//  NSString+KTExtensions.m
//  KTComponents
//
//  Copyright (c) 2004-2005 Biophony LLC. All rights reserved.
//

#import "NSString+Karelia.h"

#import "KT.h"
#import "NSCharacterSet+Karelia.h"
#import "NSData+Karelia.h"
#import "NSString-Utilities.h"

@implementation NSString ( KTExtensions )


/*!	Return the last two components of an email address or host name. Returns nil if no domain name found
 */
- (NSString *)domainName
{
	NSString *result = nil;
	
	NSRange lastDot = [self rangeOfString:@"." options:NSBackwardsSearch];
	if (NSNotFound != lastDot.location)
	{
		static NSCharacterSet *sEarlierDelimSet = nil;
		if (nil == sEarlierDelimSet)
		{
			sEarlierDelimSet = [[NSCharacterSet characterSetWithCharactersInString:@".@"] retain];
		}
		
		NSRange earlierDelim = [self rangeOfCharacterFromSet:sEarlierDelimSet options:NSBackwardsSearch range:NSMakeRange(0,lastDot.location)];
		if (NSNotFound != earlierDelim.location)
		{
			result = [self substringFromIndex:earlierDelim.location+1];
			// return string after the @ or the . to the end of the string
		}
		else
		{
			result = self;	// didn't find earlier delimeter, so string must be domain.tld
		}
	}
	return result;
}

- (BOOL) looksLikeValidHost
{
	if ([self isEqualToString:@"localhost"]) return YES;
	
	static NSCharacterSet *sIllegalHostNameSet = nil;
	static NSCharacterSet *sIllegalIPAddressSet = nil;
	if (nil == sIllegalHostNameSet)
	{
		sIllegalHostNameSet = [[[[NSCharacterSet alphanumericASCIICharacterSet] setByAddingCharactersInString:@".-"] invertedSet] retain];
		sIllegalIPAddressSet = [[[NSCharacterSet characterSetWithCharactersInString:@".0123456789"] invertedSet] retain];
	}
	
	NSRange whereBad = [self rangeOfCharacterFromSet:sIllegalHostNameSet];
	if (NSNotFound != whereBad.location)
	{
		return NO;
	}
	// now more rigorous test.
	NSArray *components = [self componentsSeparatedByString:@"."];
	
	NSRange whereBadIPAddress = [self rangeOfCharacterFromSet:sIllegalIPAddressSet];
	if (NSNotFound == whereBadIPAddress.location)
	{
		if ([components count] != 4)
		{
			return NO;	// we must have at 4 items
		}
		// We have a potential IP address, numbers only between the decimals
		NSEnumerator *theEnum = [components objectEnumerator];
		id num;
		
		while (nil != (num = [theEnum nextObject]) )
		{
			if ([num isEqualToString:@""] || [num intValue] > 255)
			{
				return NO;
			}
		}
	}
	else	// Non IP address, look for foo.bar.baz pattern
	{
		if ([components count] < 2)
		{
			return ([[self lowercaseString] isEqualToString:@"localhost"]);
			// Only localhost works if less than two components
		}
		NSString *lastComponent = [components lastObject];
		if ([lastComponent length] < 2 || ( NSNotFound != [lastComponent rangeOfString:@"-"].location) )
		{
			return NO;	// last item can't be shorter than 2 characters, can't have dash
		}
		if ([((NSString *)[components lastObject]) length] < 2)
		{
			return NO;	// last item can't be shorter than 2 characters
		}
		NSEnumerator *theEnum = [components	objectEnumerator];
		id component;
		
		while (nil != (component = [theEnum nextObject]) )
		{
			if ([component isEqualToString:@""] || [component hasPrefix:@"-"] || [component hasSuffix:@"-"])
			{
				return NO;	// two dots in a row, meaning empty inbetween, is bad.  Prefix or suffix of - is bad.
			}
		}
	}
	return YES;
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

/*	A specialised version of the above that handles URL-like strings. For example, -pathRelativeToSite returns an empty
 *	string for the home page which -pathRelativeTo: cannot handle. This method can.
 */
- (NSString *)URLPathRelativeTo:(NSString *)otherPath
{
	if ([self isEqualToString:@""])
	{
		otherPath = [@"/" stringByAppendingString:otherPath];
		NSString *result = [@"/" pathRelativeTo:otherPath];
		return result;
	}
	else
	{
		return [self pathRelativeTo:otherPath];
	}
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

@end

