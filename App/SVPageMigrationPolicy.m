//
//  SVPageMigrationPolicy.m
//  Sandvox
//
//  Created by Mike on 14/02/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVPageMigrationPolicy.h"

#import "KTDocument.h"
#import "KTPage.h"


typedef enum {
    KTCollectionSortUnspecified = -1,		// used internally
	KTCollectionUnsorted = 0, 
    KTCollectionSortAlpha,
    KTCollectionSortLatestAtBottom,
	KTCollectionSortLatestAtTop,		// = 3 ... default
	KTCollectionSortReverseAlpha,
} KTCollectionSortType;


@implementation SVPageMigrationPolicy

- (BOOL)createDestinationInstancesForSourceInstance:(NSManagedObject *)sInstance entityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError **)error
{
    // Home page of old docs tends to have @"" as filename. We want to change to nil
    if (![sInstance valueForKey:@"parent"])
    {
        [sInstance setValue:nil forKey:@"fileName"];
    }
    
    // Make sure collectionMaxFeedItemLength is appropriate
    if (![sInstance valueForKey:@"collectionTruncateCharacters"])
    {
        NSEntityDescription *dEntity = [manager destinationEntityForEntityMapping:mapping];
        NSAttributeDescription *dAttribute = [[dEntity attributesByName] objectForKey:@"collectionMaxFeedItemLength"];
        [sInstance setValue:[dAttribute defaultValue] forKey:@"collectionTruncateCharacters"];
    }
    
    BOOL result = [super createDestinationInstancesForSourceInstance:sInstance entityMapping:mapping manager:manager error:error];

    return result;
}

- (NSNumber *)thumbnailTypeFromThumbnailMediaIdentifier:(NSString *)mediaIdentifier children:(NSSet *)children;
{
    if (mediaIdentifier)
    {
        return [NSNumber numberWithInt:SVThumbnailTypeCustom];
    }
    else
    {
        if ([children count])
        {
            return [NSNumber numberWithInt:SVThumbnailTypeFirstChildItem];
        }
        else
        {
            return [NSNumber numberWithInt:SVThumbnailTypePickFromPage];
        }
    }
}

- (NSNumber *)sourceCollectionSortOrderIsAscending:(NSNumber *)sOrder;
{
    return NSBOOL([sOrder intValue] < KTCollectionSortLatestAtTop);
}

- (NSNumber *)collectionSortOrderFromSource:(NSManagedObject *)sInstance;
{
    NSNumber *sOrder = [sInstance valueForKey:@"collectionSortOrder"];
    switch ([sOrder intValue])
    {
        case KTCollectionSortAlpha:
        case KTCollectionSortReverseAlpha:
            return [NSNumber numberWithInt:SVCollectionSortAlphabetically];
            
        case KTCollectionSortLatestAtBottom:
        case KTCollectionSortLatestAtTop:
        {
            NSNumber *timestampType = [sInstance valueForKeyPath:@"master.timestampType"];
            return [NSNumber numberWithInt:([timestampType intValue] == KTTimestampCreationDate ?
                                            SVCollectionSortByDateCreated :
                                            SVCollectionSortByDateModified)];
        }
            
        default:
            return [NSNumber numberWithInt:SVCollectionSortManually];
    }
}

- (NSNumber *)collectionMaxSyndicatedPagesCount:(NSNumber *)count;
{
    if ([count intValue] < 1) count = [NSNumber numberWithInt:9999];
    return count;
}

- (NSNumber *)collectionMaxFeedItemLength:(NSNumber *)length;
{
    if (![length boolValue]) length = [NSNumber numberWithInt:1000];
    return length;
}

- (NSNumber *)collectionSyndicateTypeFromCollectionSyndicate:(NSNumber *)showArrows indexBundleIdentifier:(NSString *)indexID;
{
    // Generate a photo feed if there was an index generating RSS feed before. #109103
    NSNumber *result = [NSNumber numberWithInt:(indexID && [showArrows boolValue] ? 2 : 0)];
    return result;
}

- (NSNumber *)navigationArrowsStyleFromShowNavigationArrows:(NSNumber *)showArrows indexBundleIdentifier:(NSString *)indexID;
{
    if (!indexID) return NSBOOL(NO);    // 109090
    
    if ([showArrows boolValue])
    {
        if ([indexID isEqualToString:@"sandvox.PhotoGridIndex"])
        {
            return [NSNumber numberWithInt:1];
        }
        else
        {
            return [NSNumber numberWithInt:2];
        }
    }
    else
    {
        return showArrows;
    }
}

- (NSString *)RSSFileNameFromExtensiblePropertiesData:(NSData *)data;
{
    // If a value was ever set, use it. Otherwise fall back to prefs. #100026
    NSString *result = [[KSExtensibleManagedObject unarchiveExtensibleProperties:data] objectForKey:@"RSSFileName"];
    if (!result) result = [[NSUserDefaults standardUserDefaults] objectForKey:@"RSSFileName"];
    return result;
}

- (NSNumber *)shouldUpdateFileNameWhenTitleChangesFromSource:(NSManagedObject *)sInstance;
{
    NSData *data = [sInstance valueForKey:@"extensiblePropertiesData"];
    NSDictionary *extensibelProps = [KSExtensibleManagedObject unarchiveExtensibleProperties:data];
    NSNumber *result = [extensibelProps objectForKey:@"shouldUpdateFileNameWhenTitleChanges"];
    
    if (!result)
    {
        result = NSBOOL(![sInstance valueForKey:@"publishedPath"] &&
                        ![extensibelProps objectForKey:@"publishedDataDigest"]);
    }
    
    return result;
}

- (NSData *)extensiblePropertiesData;
{
    NSDictionary *props = [NSDictionary dictionaryWithObject:NSBOOL(YES) forKey:@"migrateRawHTMLOnNextEdit"];
    NSData *result = [KSExtensibleManagedObject archiveExtensibleProperties:props];
    return result;
}

@end


#pragma mark -


@interface KTExtensiblePluginPropertiesArchivedObject : NSObject <NSCoding>
{
	NSString *myClassName;
	NSString *myEntityName;
	NSString *myObjectIdentifier;
}
@end

@implementation KTExtensiblePluginPropertiesArchivedObject

- (id)initWithClassName:(NSString *)className entityName:(NSString *)entityName ID:(NSString *)ID
{
    [super init];
    
    myClassName = [className copy];
	myEntityName = [entityName copy];
	myObjectIdentifier = [ID copy];
	
	return self;
}

- (id)initWithCoder:(NSCoder *)decoder
{
	[super init];
	
	myClassName = [[decoder decodeObjectForKey:@"class"] copy];
	myEntityName = [[(NSKeyedUnarchiver *)decoder decodeObjectForKey:@"entityName"] copy];
	myObjectIdentifier = [[(NSKeyedUnarchiver *)decoder decodeObjectForKey:@"objectIdentifier"] copy];
	
	return self;
}

- (void)dealloc
{
	[myClassName release];
	[myEntityName release];
	[myObjectIdentifier release];
	
	[super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:myClassName forKey:@"class"];
	[encoder encodeObject:myEntityName forKey:@"entityName"];
	[encoder encodeObject:myObjectIdentifier forKey:@"objectIdentifier"];
}

@end


#pragma mark -


@implementation SVMasterMigrationPolicy

- (NSData *)extensiblePropertiesData;
{
    NSDictionary *props = [NSDictionary dictionaryWithObject:NSBOOL(YES) forKey:@"migrateRawHTMLOnNextEdit"];
    NSData *result = [KSExtensibleManagedObject archiveExtensibleProperties:props];
    return result;
}

@end

