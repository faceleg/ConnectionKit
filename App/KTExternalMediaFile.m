//
//  KTExternalMediaFile.m
//  Marvel
//
//  Created by Mike on 11/12/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "KTExternalMediaFile.h"
#import "KTMediaFile+Internal.h"

#import "NSManagedObject+KTExtensions.h"

#import "BDAlias.h"
#import "BDAlias+QuickLook.h"


@implementation KTExternalMediaFile

#pragma mark -
#pragma mark Init

+ (id)insertNewMediaFileWithPath:(NSString *)path inManagedObjectContext:(NSManagedObjectContext *)moc
{
	KTExternalMediaFile *result = [super insertNewMediaFileWithPath:path inManagedObjectContext:moc];
	
	[result setAlias:[BDAlias aliasWithPath:path]];
	
	return result;
}

#pragma mark -
#pragma mark Other

+ (NSString *)entityName { return @"ExternalMediaFile"; }

- (BDAlias *)alias
{
	BDAlias *result = [self wrappedValueForKey:@"alias"];
	
	if (!result)
	{
		NSData *aliasData = [self valueForKey:@"aliasData"];
		if (aliasData)
		{
			result = [BDAlias aliasWithData:aliasData];
			[self setPrimitiveValue:result forKey:@"alias"];
		}
	}
	
	return result;
}

- (void)setAlias:(BDAlias *)alias
{
	[self setWrappedValue:alias forKey:@"alias"];
	[self setValue:[alias aliasData] forKey:@"aliasData"];
}

- (NSString *)currentPath;
{
	NSString *result = [[self alias] fullPath];
	
	// Ignore files which are in the Trash
	if ([result rangeOfString:@".Trash"].location != NSNotFound)
	{
		result = nil;
	}
	
	return result;
}

- (NSString *)quickLookPseudoTag
{
	NSString *result = [[self alias] quickLookPseudoTag];
	return result;
}

- (NSString *)preferredFileName
{
	NSString *result = [[[self valueForKeyPath:@"alias.lastKnownPath"] lastPathComponent] stringByDeletingPathExtension];
	return result;
}

@end
