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

#import "assertions.h"


@implementation KTArchivePage

+ (NSString *)entityName { return @"ArchivePage"; }

/*	We want to basically clone the main index page but with a few differences.
 */
- (NSString *)contentHTMLWithParserDelegate:(id)parserDelegate isPreview:(BOOL)isPreview;
{
	KTHTMLParser *parser = [[KTHTMLParser alloc] initWithPage:[self parent]];
	[parser setDelegate:parserDelegate];
	
	if (isPreview) {
		[parser setHTMLGenerationPurpose:kGeneratingPreview];
	} else {
		[parser setHTMLGenerationPurpose:kGeneratingRemote];
	}
	
	[parser setCurrentPage:self];
	[parser overrideKey:@"master" withValue:[[self parent] master]];
	[parser overrideKey:@"titleHTML" withValue:[self valueForKey:@"titleHTML"]];
	[parser overrideKey:@"titleText" withValue:[self titleText]];
	
	NSString *result = [parser parseTemplate];
	[parser release];
	return result;
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
