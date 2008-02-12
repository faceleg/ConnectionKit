//
//  NSString+QuickLook.h
//  SandvoxQuickLook
//
//  Created by Dan Wood on 11/28/07.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSString ( QuickLook )

+ (NSString *)stringWithHTMLData:(NSData *)aData;
- (NSStringEncoding)encodingFromCharset;

- (NSRange)rangeFromString:(NSString *)inString1 toString:(NSString *)inString2;
- (NSRange)rangeFromString:(NSString *)inString1 toString:(NSString *)inString2 options:(unsigned)inMask;
- (NSRange)rangeFromString:(NSString *)inString1 toString:(NSString *)inString2 options:(unsigned)inMask range:(NSRange)inSearchRange;

- (NSRange)rangeBetweenString:(NSString *)inString1 andString:(NSString *)inString2;
- (NSRange)rangeBetweenString:(NSString *)inString1 andString:(NSString *)inString2
					  options:(unsigned)inMask;
- (NSRange)rangeBetweenString:(NSString *)inString1 andString:(NSString *)inString2
					  options:(unsigned)inMask range:(NSRange)inSearchRange;

- (float) floatVersion;
- (NSString *) removeWhiteSpace;

- (NSString *) replaceAllTextBetweenString:(NSString *)inString1 andString:(NSString *)inString2
							fromDictionary:(NSDictionary *)inDict
								   options:(unsigned)inMask range:(NSRange)inSearchRange;

- (NSString *) replaceAllTextBetweenString:(NSString *)inString1 andString:(NSString *)inString2
							fromDictionary:(NSDictionary *)inDict
								   options:(unsigned)inMask;

- (NSString *) replaceAllTextBetweenString:(NSString *)inString1 andString:(NSString *)inString2
							fromDictionary:(NSDictionary *)inDict;

@end
