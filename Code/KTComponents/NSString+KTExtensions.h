//
//  NSString+KTExtensions.h
//  KTComponents
//
//  Copyright (c) 2005-2006, Karelia Software. All rights reserved.
//
//  THIS SOFTWARE IS PROVIDED BY KARELIA SOFTWARE AND ITS CONTRIBUTORS "AS-IS"
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

#import <Foundation/Foundation.h>

typedef enum { kCompareUnknown = 0, kCompareNotEmpty, kCompareEquals, kCompareNotEquals,
	kCompareLess, kCompareLessEquals, kCompareMore, kCompareMoreEquals, kCompareOr, kCompareAnd,
	kCompareNotEmptyOrEditing } ComparisonType;

@interface NSString ( KTExtensions )

- (NSString *)legalizeURLNameWithFallbackID:(NSString *)idString;
- (NSString *)legalizeFileNameWithFallbackID:(NSString *)idString;
- (NSString *)normalizeUnicode;

+ (NSString *)stringWithData:(NSData *)data encoding:(NSStringEncoding)encoding;
+ (NSString *)stringWithHTMLData:(NSData *)aData;

+ (NSString *)GUIDString;
+ (NSString *)shortGUIDString;

- (NSString *)firstLetterCapitalizedString;

- (BOOL)isEmptyString;
- (BOOL)isValidEmailAddress;

- (NSArray *)componentsSeparatedByWhitespace;
- (NSArray *)componentsSeparatedByCommas;
- (ComparisonType)parseComparisonintoLeft:(NSString **)left right:(NSString **)right;

- (NSString *)flattenHTML;
- (NSString *)stringByRemovingCharactersInSet:(NSCharacterSet *)set;
- (NSString *)stringByRemovingCharactersNotInSet:(NSCharacterSet *)validCharacters;
- (NSStringEncoding)encodingFromCharset;
+ (NSString *)charsetFromEncoding:(NSStringEncoding)anEncoding;

- (NSString *)trimFirstLine;
- (NSString *)trim;

- (NSString *)stringByAppendingDirectoryTerminator;

- (NSString *)breakBetweenLines;
- (NSString *)escapedEntities;
- (NSString *)escapeCharactersOutOfEncoding:(NSStringEncoding)anEncoding;
- (NSString *)escapeCharactersOutOfCharset:(NSString *)aCharset;

- (NSString *)unescapedEntities;
- (NSArray *)componentsSeparatedByLineSeparators;
- (NSArray *)componentsSeparatedByLineSeparatorsWithNewlines;

// Paths
- (NSString *)stringBySubstitutingRightArrowForPathSeparator;
- (NSString *)HTMLdirectoryPath;
- (NSString *)pathRelativeTo:(NSString *)otherPath;

- (NSString *)urlEncode;
- (NSString *)urlEncodeNoPlus;
- (NSString *)urlDecode;
- (NSString *)encodeLegally;
+ (NSString *)stringWithUnichar:(unichar) inChar;
- (NSString *)removeMultipleNewlines;

- (unsigned)checksum:(unsigned)aPrime;

	/*!	Decode the query section of a URL, returning a dictionary of its values
	*/
- (NSDictionary *)queryParameters;

/*! returns as a URL string with, if nothing else, an http:// scheme */
- (NSString *)stringWithValidURLScheme;

- (NSRange)rangeFromString:(NSString *)inString1 toString:(NSString *)inString2;
- (NSRange)rangeFromString:(NSString *)inString1 toString:(NSString *)inString2 options:(unsigned)inMask;
- (NSRange)rangeFromString:(NSString *)inString1 toString:(NSString *)inString2 options:(unsigned)inMask range:(NSRange)inSearchRange;

- (NSRange)rangeBetweenString:(NSString *)inString1 andString:(NSString *)inString2;
- (NSRange)rangeBetweenString:(NSString *)inString1 andString:(NSString *)inString2 options:(unsigned)inMask;
- (NSRange)rangeBetweenString:(NSString *)inString1 andString:(NSString *)inString2 options:(unsigned)inMask range:(NSRange)inSearchRange;

- (NSString *) replaceAllTextBetweenString:(NSString *)inString1 andString:(NSString *)inString2
							fromDictionary:(NSDictionary *)inDict
								   options:(unsigned)inMask range:(NSRange)inSearchRange;

- (NSString *) replaceAllTextBetweenString:(NSString *)inString1 andString:(NSString *)inString2
							fromDictionary:(NSDictionary *)inDict
								   options:(unsigned)inMask;

- (NSString *) replaceAllTextBetweenString:(NSString *)inString1 andString:(NSString *)inString2
							fromDictionary:(NSDictionary *)inDict;

-(NSAttributedString *)parseHTML;


- (NSString *) crunchWhiteSpace;	// remove runs of spaces, newlines, etc.
- (NSString *) condenseWhiteSpace;	// remove runs of spaces, newlines, etc.
									// replacing with a single space
- (NSString *) condenseMultipleCharactersFromSet:(NSCharacterSet *)aMultipleSet into:(unichar)aReplacement;
- (NSString *) removeWhiteSpace;

// REGISTRATION
// obfuscation
#ifndef DEBUG
#define rot13 encodeAsURL
#endif

- (NSString *)rot13;

- (float) floatVersion;

#pragma mark UTIs

//  convert from UTI
+ (NSString *)filenameExtensionForUTI:(NSString *)aUTI;
+ (NSString *)MIMETypeForUTI:(NSString *)aUTI;
+ (NSString *)pboardTypeForUTI:(NSString *)aUTI;

+ (NSString *)fileTypeForUTI:(NSString *)aUTI;
+ (OSType)OSTypeForUTI:(NSString *)aUTI;

//  convert to UTI
+ (NSString *)UTIForFileAtPath:(NSString *)anAbsoultePath;

+ (NSString *)UTIForFilenameExtension:(NSString *)anExtension;
+ (NSString *)UTIForMIMEType:(NSString *)aMIMEType;
+ (NSString *)UTIForPboardType:(NSString *)aPboardType;

+ (NSString *)UTIForFileType:(NSString *)aFileType;
+ (NSString *)UTIForOSType:(OSType)anOSType;

// check equality
+ (BOOL)UTI:(NSString *)aUTI isEqualToUTI:(NSString *)anotherUTI;

// Check conformance
+ (BOOL)UTI:(NSString *)aUTI conformsToUTI:(NSString *)aConformsToUTI;

@end

