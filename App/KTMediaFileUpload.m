//
//  KTMediaFileUpload.m
//  Marvel
//
//  Created by Mike on 09/12/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "KTMediaFileUpload.h"

#import "KTDocumentInfo.h"
#import "KTHostProperties.h"
#import "KTPage.h"
#import "KTMediaPersistentStoreCoordinator.h"

#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSString+KTExtensions.h"


@implementation KTMediaFileUpload

/*	Combines the site URL and our path relative to it to build the full URL
 */
- (NSURL *)absoluteURL;
{
	KTMediaPersistentStoreCoordinator *PSC = (id)[[self managedObjectContext] persistentStoreCoordinator];
	OBASSERT(PSC);
	OBASSERT([PSC isKindOfClass:[KTMediaPersistentStoreCoordinator class]]);
	
	KTDocument *document = [[PSC mediaManager] document];
	KTHostProperties *hostProperties = [[document documentInfo] hostProperties];
	NSURL *siteURL = [hostProperties siteURL];
	
	NSURL *result = [NSURL URLWithString:[self pathRelativeToSite] relativeToURL:siteURL];
	return [result absoluteURL];
}

- (NSString *)pathRelativeToSite;
{
	NSString *result = [self wrappedValueForKey:@"pathRelativeToSite"];
	return result;
}

/*	Make sure that once the path has been set it can't be changed
 */
- (void)setPathRelativeToSite:(NSString *)path
{
	if ([self valueForKey:@"pathRelativeToSite"])
	{
		[NSException raise:NSInvalidArgumentException
					format:@"-[KTMediaFileUpload pathRelativeToSite] is immutable"];
	}
	else
	{
		[self setWrappedValue:path forKey:@"pathRelativeToSite"];
	}
}

- (NSString *)pathRelativeTo:(id <KTWebPaths>)path2;
{
	NSString *result = [[self pathRelativeToSite] URLPathRelativeTo:[path2 pathRelativeToSite]];
	return result;
}

@end
