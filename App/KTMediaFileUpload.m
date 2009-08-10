//
//  KTMediaFileUpload.m
//  Marvel
//
//  Created by Mike on 09/12/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "KTMediaFileUpload.h"

#import "KTSite.h"
#import "KTHostProperties.h"
#import "KTPage.h"
#import "KTMediaPersistentStoreCoordinator.h"
#import "KTMediaFile.h"

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
	KTHostProperties *hostProperties = [[document site] hostProperties];
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
		NSLog(@"Changing -pathRelativeToSite from %@ to %@. You should ONLY do this as a result of validation.",
        [self pathRelativeToSite],
              path);
	}
	
    [self setWrappedValue:path forKey:@"pathRelativeToSite"];
}

- (BOOL)validateValue:(id *)value forKey:(NSString *)key error:(NSError **)error
{
    BOOL result = [super validateValue:value forKey:key error:error];
    
    if (nil != value && result && [key isEqualToString:@"pathRelativeToSite"])
    {
        NSString *path = *value;
        if (![NSURL URLWithString:path])    // A fairly quick, neat way to test conformance
        {
            NSString *fileName = [[path lastPathComponent] stringByDeletingPathExtension];
            NSString *legalizedFileName = [fileName legalizedWebPublishingFileName];
            
            NSString *legalizedPath = [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:
                                       [legalizedFileName stringByAppendingPathExtension:
                                        [path pathExtension]]];
            
            NSString *uniquePath = [[self valueForKey:@"file"] uniqueUploadPath:legalizedPath];
            *value = uniquePath;
        }
        else if ([path isEqualToString:[[NSUserDefaults standardUserDefaults] valueForKey:@"DefaultMediaPath"]])
        {
            // Case 40782. Poor bloke somehow has a file publishing directly as "_Media"
            result = NO;
        }
    }
    
    return result;
}

- (NSDictionary *)scalingProperties
{
	return [self transientValueForKey:@"scalingProperties" persistentArchivedDataKey:@"scalingPropertiesData"];
}

- (void)setScalingProperties:(NSDictionary *)properties
{
	[self setTransientValue:properties forKey:@"scalingProperties" persistentArchivedDataKey:@"scalingPropertiesData"];
}

@end
