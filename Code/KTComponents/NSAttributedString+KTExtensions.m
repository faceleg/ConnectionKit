//
//  NSAttributedString+KTExtensions.m
//  KTComponents
//
//  Created by Dan Wood on 11/11/04.
//  Copyright 2004 Karelia Software, LLC. All rights reserved.
//

#import "NSAttributedString+KTExtensions.h"

#import "Debug.h"
#import "KT.h"
#import "NSCharacterSet+KTExtensions.h"
#import "NSImage+KTExtensions.h"
#import "NSString+KTExtensions.h"
#import "NSColor+KTExtensions.h"

static NSCharacterSet *sNonWebPunctuationSet;
static NSCharacterSet *sWhitespaceAndDelimeterSet;

@implementation NSAttributedString ( KTExtensions )

/*!	Convenience method, since we need quick autoreleased strings.
*/
+ (id)stringWithString:(NSString *)string attributes:(NSDictionary *)attrs
{
	return [[[NSAttributedString alloc] initWithString:string attributes:attrs] autorelease];
}

+ (id)systemFontStringWithString:(NSString *)string
{
	static NSDictionary *sSystemFontDict = nil;
	if (nil == sSystemFontDict)
	{
		sSystemFontDict = [[NSDictionary alloc] initWithObjectsAndKeys:
			[NSFont systemFontOfSize:[NSFont systemFontSize]], NSFontAttributeName,
			nil];
	}
	return [[[NSAttributedString alloc] initWithString:string attributes:sSystemFontDict] autorelease];
}

+ (id)stringFromImagePath:(NSString *)aPath
{
//	NSFileWrapper *wrapper = [[[NSFileWrapper alloc] initWithPath:aPath] autorelease];
	NSImage *image = [[[NSImage alloc] initWithContentsOfFile:aPath] autorelease];
	[image setScalesWhenResized:YES];
	[image setSize:NSMakeSize(32.0,32.0)];
	NSFileWrapper *wrapper = [[NSFileWrapper alloc] init];
	[wrapper setIcon:image];
	
	NSTextAttachment *attachment = [[[NSTextAttachment alloc] initWithFileWrapper:wrapper] autorelease];
	NSAttributedString *result = [NSAttributedString attributedStringWithAttachment:attachment];
	return result;
}

// methods for reading files and converting to HTML

+ (id)attributedStringWithURL:(NSURL *)aURL documentAttributes:(NSDictionary **)dict
{
	NSError *localError;
	NSAttributedString *attr = [[NSAttributedString alloc] initWithURL:aURL options:nil documentAttributes:dict error:&localError];
	
	if ( nil == attr )
	{
		[NSException raise:kKTGenericObjectException format:@"attributedStringWithURL:%@ ..., error:%@", [aURL path], [localError localizedDescription]];
		return NO;
	}
	
	return [attr autorelease];
}

- (NSString *)snippetExcludingElements:(NSSet *)aSet
{
	NSMutableSet *excludedElements = [NSMutableSet setWithSet:aSet];
	
	// remove funky Apple whitespace options
	[excludedElements addObject:@"Apple-converted-space"];
	[excludedElements addObject:@"Apple-converted-tab"];
	[excludedElements addObject:@"Apple-interchange-newline"];
	[excludedElements addObject:@"Apple-style-span"];

	// bare snippets
	[excludedElements addObjectsFromArray:[NSArray arrayWithObjects:@"DOCTYPE", @"HTML", @"XML", @"HEAD", @"BODY", @"FONT", nil]];
		
	NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
	[attributes setObject:NSHTMLTextDocumentType forKey:NSDocumentTypeDocumentAttribute];
	[attributes setObject:[excludedElements allObjects] forKey:NSExcludedElementsDocumentAttribute];
	[attributes setObject:[NSNumber numberWithInt:2] forKey:NSPrefixSpacesDocumentAttribute];
	
	NSError *localError;
	NSData *data = [self dataFromRange:NSMakeRange(0,[self length])
					documentAttributes:attributes
								 error:&localError];
	
	if ( nil == data )
	{
		[NSException raise:kKTGenericObjectException format:@"standardSnippet error:%@", [localError localizedDescription]];
		return nil;
	}
	
	return [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];	
}

- (NSString *)boldItalicOnlySnippet
{
	return [self snippetExcludingElements:[NSSet setWithObjects:@"p", @"div", @"span", @"style", nil]];
}

- (NSString *)standardSnippet
{
	return [self snippetExcludingElements:nil];
}

// Additions to NSMutableAttributedString to find URLs
// and mark them with the appropriate property
// Tab Size: 3
// Copyright (c) 2002 Aaron Sittig

// (Actually, see license in package, available at http://blackholemedia.com/code)

/*!	This returns a new attributed string where recognizeable URL "words" (separated by blank space or < >, and not ending with punctuation) are given a hyperlink attribute.  This allows us to, as desired, take regular attributed string text and get make hyperlinks easily. 
*/

static NSURL* findURL(NSString* string);

- (NSAttributedString *)hyperlinkedURLs
{
	if (nil == sNonWebPunctuationSet)	// create both static sets
	{
		sNonWebPunctuationSet = [[[NSCharacterSet punctuationCharacterSet] setByRemovingCharactersInString:@"/_"] retain];
		// Eliminate ASCII punctuation from !"#%&'()*,-./:;?@[\]_{} that seem reasonable for being at the end of a URL
		
		sWhitespaceAndDelimeterSet = [[[NSCharacterSet whitespaceAndNewlineCharacterSet] setByAddingCharactersInString:@"<>"] retain];
	}

	NSMutableAttributedString *result = [[self mutableCopyWithZone:[self zone]] autorelease];
	NSScanner*					scanner = [NSScanner scannerWithString:[self string]];
	NSRange						scanRange;
	NSString*					scanString;
	NSURL*						foundURL;
	NSDictionary*				linkAttr;
	
	[scanner setCharactersToBeSkipped:sWhitespaceAndDelimeterSet];
	
	// Start Scan
	while( ![scanner isAtEnd] )
	{
		// Pull out a token delimited by whitespace or new line
		[scanner scanUpToCharactersFromSet:sWhitespaceAndDelimeterSet intoString:&scanString];
		int length = [scanString length];
		
		// Now back up if we have a large enough string, that ends in punctuation
		if (length > 5 && [sNonWebPunctuationSet characterIsMember:[scanString characterAtIndex:length-1] ])
		{
			length--;
			scanString = [scanString substringToIndex:length];	// remove last char
			[scanner setScanLocation:[scanner scanLocation] - 1];
		}

		scanRange.length = length;
		scanRange.location = [scanner scanLocation] - length;

		// If we find a url modify the string attributes
		if(( foundURL = findURL(scanString) ))
		{
			NSString *urlString = [foundURL absoluteString];	// we want a string
																// Apply underline style and link color
			linkAttr = [NSDictionary dictionaryWithObjectsAndKeys:
				urlString, NSLinkAttributeName,
				[NSNumber numberWithInt:NSSingleUnderlineStyle], NSUnderlineStyleAttributeName,
				[NSColor linkColor],
				// ^^ link color to match what HTML parsing does
				NSForegroundColorAttributeName, NULL ];
			[result addAttributes:linkAttr range:scanRange];
		}
	}
	return result;
}

NSURL* findURL(NSString* string)
{
	NSRange		theRange;
	
	// Look for ://
	theRange = [string rangeOfString:@"://"];
	if( theRange.location != NSNotFound && theRange.length != 0 )
		return [NSURL URLWithString:[string encodeLegally]];
	
	// Look for www. at start
	theRange = [string rangeOfString:@"www."];
	if( theRange.location == 0 && theRange.length == 4 )
		return [NSURL URLWithString:[[NSString stringWithFormat:@"http://%@", string] encodeLegally]];
	
	// Look for ftp. at start
	theRange = [string rangeOfString:@"ftp."];
	if( theRange.location == 0 && theRange.length == 4 )
		return [NSURL URLWithString:[[NSString stringWithFormat:@"ftp://%@", string] encodeLegally]];
	
	// Look for mailto: at start
	theRange = [string rangeOfString:@"mailto:"];
	if( theRange.location == 0 && theRange.length == 7 )
		return [NSURL URLWithString:[string encodeLegally]];
	
	return nil;
}

- (NSData *)archivableData
{
	NSData *result = nil;
	
	NSError *error = nil;
	NSRange range = NSMakeRange(0,[self length]);
	NSDictionary *documentAttributes = [NSDictionary dictionaryWithObject:NSRTFTextDocumentType forKey:NSDocumentTypeDocumentAttribute];
	
	result = [self dataFromRange:range documentAttributes:documentAttributes error:&error];
	
	if ( nil != error )
	{
		result = nil;
		LOG((@"could not create archivableData from attributed string: %@", self));
	}
	
	return result;
}

+ (NSAttributedString *)attributedStringWithArchivedData:(NSData *)archivedData
{
	if ( nil == archivedData )
	{
		return nil;
	}
	NSDictionary *options = [NSDictionary dictionary];
	NSAttributedString *result = [[NSAttributedString alloc] initWithData:archivedData options:options documentAttributes:nil error:nil];
	
	return [result autorelease];
}

@end
