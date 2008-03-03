//
//  KTArchivePage.m
//  Marvel
//
//  Created by Mike on 29/02/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTArchivePage.h"
#import "KTPage.h"

#import "KTHTMLParser.h"

#import "NSBundle+KTExtensions.h"

#import "assertions.h"


@implementation KTArchivePage

+ (NSString *)entityName { return @"ArchivePage"; }

/*	Use a different template to most pages
 */
+ (NSString *)pageMainContentTemplate
{
	static NSString *sPageTemplateString = nil;
	
	if (!sPageTemplateString)
	{
		NSString *path = [[NSBundle bundleForClass:[self class]] overridingPathForResource:@"KTArchivePageTemplate" ofType:@"html"];
		NSData *data = [NSData dataWithContentsOfFile:path];
		sPageTemplateString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	}
	
	return sPageTemplateString;
}

- (NSString *)designDirectoryPath
{
	return [[self parent] designDirectoryPath];
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

- (KTMaster *)master { return [[self parent] master]; }

- (void)awakeFromInsert
{
	[super awakeFromInsert];
	[self setTitleText:@"Collection archive test"];
}

@end
