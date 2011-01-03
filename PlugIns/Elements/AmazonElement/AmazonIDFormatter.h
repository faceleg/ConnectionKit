//
//  AmazonIDFormatter.h
//  Amazon List
//
//  Created by Mike on 05/03/2007.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//
//	A subclass of TrimmedStringFormatter. The standard trimming
//	behaviour is extended. The formatter tests if the entered string
//	is a URL. If not, all non-alphanumeric characters are removed
//	and the remaining characters converted to uppercase.


#import <Cocoa/Cocoa.h>
#import "KSTrimFirstLineFormatter.h"


@interface AmazonIDFormatter : KSTrimFirstLineFormatter
{
}

+ (NSCharacterSet *)legalAmazonIDCharacters;

@end


@interface NSString (AmazonList)

- (BOOL)isValidISBN10Number;
- (BOOL)isValidISBN13Number;
- (BOOL)isValidISBNNumber;

- (NSString *)substringFromPrefix:(NSString *)prefix;
@end