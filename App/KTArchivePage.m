//
//  KTArchivePage.m
//  Marvel
//
//  Created by Mike on 29/02/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTArchivePage.h"

#import "assertions.h"


@implementation KTArchivePage

+ (NSString *)entityName { return @"ArchivePage"; }

- (NSString *)contentHTMLWithParserDelegate:(id)parserDelegate isPreview:(BOOL)isPreview;
{
	NSString *result = [[self parent] contentHTMLWithParserDelegate:parserDelegate isPreview:isPreview];
	return result;
}

/*	Hacks to override KSExtensibleManagedObject
 */
- (id)valueForUndefinedKey:(NSString *)key
{
	OBASSERT_NOT_REACHED("");
	return nil;
	return [super valueForUndefinedKey:key];
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key
{
	OBASSERT_NOT_REACHED("");
	[super setValue:value forUndefinedKey:key];
}

- (KTElementPlugin *)plugin { return nil; }

- (void)awakeFromInsert
{
	[super awakeFromInsert];
	[self setTitleText:@"Collection archive test"];
}

@end
