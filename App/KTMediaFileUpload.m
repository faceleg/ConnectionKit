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

#import "NSError+Karelia.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSString+Karelia.h"
#import "NSString+KTExtensions.h"


@implementation KTMediaFileUpload

/*	Combines the site URL and our path relative to it to build the full URL
 */
- (NSURL *)URL;
{
	KTMediaPersistentStoreCoordinator *PSC = (id)[[self managedObjectContext] persistentStoreCoordinator];
	OBASSERT(PSC);
	OBASSERT([PSC isKindOfClass:[KTMediaPersistentStoreCoordinator class]]);
	
	KTDocument *document = [[PSC mediaManager] document];
	KTHostProperties *hostProperties = [[document documentInfo] hostProperties];
	NSURL *siteURL = [hostProperties siteURL];
	
	NSURL *result = [NSURL URLWithString:[self pathRelativeToSite] relativeToURL:siteURL];
	return result;
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

- (BOOL)validateValue:(id *)value forKey:(NSString *)key error:(NSError **)error
{
    BOOL result = [super validateValue:value forKey:key error:error];
    
    if (result && [key isEqualToString:@"pathRelativeToSite"])
    {
        NSString *path = *value;
        NSString *fileName = [[path lastPathComponent] stringByDeletingPathExtension];
        NSString *legalizedFileName = [fileName legalizedWebPublishingFilename];
        
        if (![fileName isEqualToString:legalizedFileName])
        {
            NSString *legalizedPath = [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:
                                       [legalizedFileName stringByAppendingPathExtension:
                                        [path pathExtension]]];
            
            *value = legalizedPath;
        }
    }
    
    return result;
}

@end
