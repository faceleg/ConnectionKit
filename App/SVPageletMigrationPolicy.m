//
//  SVPageletMigrationPolicy.m
//  Sandvox
//
//  Created by Mike on 15/02/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVPageletMigrationPolicy.h"

#import "SVGraphicFactory.h"
#import "SVMediaMigrationPolicy.h"
#import "SVLink.h"

#import "NSError+Karelia.h"


@implementation SVPageletMigrationPolicy

- (BOOL)createDestinationInstancesForSourceInstance:(NSManagedObject *)sInstance entityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError **)error;
{
    @try
    {
        BOOL result = [super createDestinationInstancesForSourceInstance:sInstance
                                                           entityMapping:mapping
                                                                 manager:manager
                                                                   error:error];
        return result;
    }
    @catch (NSException *exception)
    {
        // Migration manager seems to handle NSObjectInaccessibleExceptions itself
        if ([[exception name] isEqualToString:NSObjectInaccessibleException])
        {
            @throw exception;
        }
        
        if (error)
        {
            *error = [KSError errorWithDomain:NSCocoaErrorDomain
                                         code:NSEntityMigrationPolicyError
                   localizedDescriptionFormat:NSLocalizedString(@"%@ plug-in threw an exception while migrating", "migration error"), [sInstance valueForKey:@"pluginIdentifier"]];
        }
        
        return NO;
    }
    return YES;
}

- (void)propagateSidebarRelationshipForDestinationPagelet:(NSManagedObject *)dInstance toDescendantsOfPage:(NSManagedObject *)sPage manager:(NSMigrationManager *)manager
{
    NSSet *sPages = [[sPage valueForKey:@"children"]
                     filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"includeInheritedSidebar == 1"]];
    
    NSArray *dSidebars = [manager destinationInstancesForEntityMappingNamed:@"PageToSidebar"
                                                            sourceInstances:[sPages allObjects]];
    
    [[dInstance mutableSetValueForKey:@"sidebars"] addObjectsFromArray:dSidebars];
    
    
    // Truck on brother
    for (NSManagedObject *aPage in sPages)
    {
        [self propagateSidebarRelationshipForDestinationPagelet:dInstance toDescendantsOfPage:aPage manager:manager];
    }
}

- (BOOL)createRelationshipsForDestinationInstance:(NSManagedObject *)dInstance entityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError **)error;
{
    BOOL result = [super createRelationshipsForDestinationInstance:dInstance entityMapping:mapping manager:manager error:error];
    if (!result) return result;
    
    
    if ([[mapping sourceEntityName] isEqualToString:@"Pagelet"])
    {
        NSManagedObject *sPagelet = [[manager sourceInstancesForEntityMappingNamed:[mapping name] destinationInstances:[NSArray arrayWithObject:dInstance]] lastObject];
        
        // Only interested in sidebar pagelets
        if ([dInstance valueForKey:@"textAttachment"]) return YES;
        if ([[sPagelet valueForKey:@"location"] intValue] != 1) return YES;
        
        
        // Locate corresponding sidebar object and add pagelet to it
        NSManagedObject *sPage = [sPagelet valueForKey:@"page"];
        if (sPage)
        {
            NSArray *dSidebars = [manager destinationInstancesForEntityMappingNamed:@"PageToSidebar" sourceInstances:[NSArray arrayWithObject:sPage]];
            
            [[dInstance mutableSetValueForKey:@"sidebars"] addObjectsFromArray:dSidebars];
            
            
            // Carry on down the tree?
            if ([[sPagelet valueForKey:@"shouldPropagate"] boolValue])
            {
                [self propagateSidebarRelationshipForDestinationPagelet:dInstance toDescendantsOfPage:sPage manager:manager];
            }
        }
    }
    
    return YES;
}

- (NSString *)plugInIdentifierFromIdentifier:(NSString *)identifier;
{
    // Convert RSS to Digg. #82975
    /*if ([identifier isEqualToString:@"sandvox.DiggElement"])
    {
        identifier = @"sandvox.FeedElement";
    }
    // Convert Index Pagelet to General Index
    else*/ if ([identifier isEqualToString:@"sandvox.IndexElement"])
    {
        identifier = @"sandvox.GeneralIndex";
    }
    // Convert External Link to External Page
    else if ([identifier isEqualToString:@"sandvox.LinkElement"])
    {
        identifier = @"sandvox.IFrameElement";
    }
    
    return identifier;
}

- (NSNumber *)sortKeyForPagelet:(NSManagedObject *)sPagelet;
{
    // Only sidebar pagelets get a sort key
    if ([[sPagelet valueForKey:@"location"] intValue] != 1) return nil;
    
    
    // Start out with the old ordering value
    NSInteger result = [[sPagelet valueForKey:@"ordering"] integerValue];
    
    // Adjust by 50 corresponding to depth in tree. Thus, original inherited ordering will be maintained provided the user doesn't have pages 10 deep!
    NSUInteger depth = 0;
    KTPage *parent = [sPagelet valueForKeyPath:@"page.parent"];
    while (parent)
    {
        depth++;
        parent = [parent valueForKey:@"parent"];
    }
    
    // Apply offset, based off old .prefersBottom setting
    if ([[sPagelet valueForKey:@"prefersBottom"] boolValue])
    {
        result += 1000 - 50*depth;
    }
    else
    {
        result += 50*depth;
    }
    
    
    return [NSNumber numberWithInteger:result];
}

- (NSData *)extensiblePropertiesDataFromSource:(NSManagedObject *)sInstance plugInIdentifier:(NSString *)identifier;
{
    identifier = [self plugInIdentifierFromIdentifier:identifier];  // handle Digg
    
    SVGraphicFactory *factory = [SVGraphicFactory factoryWithIdentifier:identifier];
    if (!factory)
    {
        NSLog(@"%@ plug-in not found for migration", identifier);
    }
    
    SVPlugIn *plugIn = [[[factory plugInClass] alloc] init];
    
    [plugIn awakeFromSourceInstance:sInstance];
    
    
    // Serialize the plug-in
    NSMutableDictionary *serializedProperties = [[NSMutableDictionary alloc] init];
    for (NSString *aKey in [[plugIn class] plugInKeys])
    {
        id value = [plugIn serializedValueForKey:aKey];
        if (value) [serializedProperties setObject:value forKey:aKey];
    }
    
    [plugIn release];
    
    NSData *result = [KSExtensibleManagedObject archiveExtensibleProperties:serializedProperties];
    [serializedProperties release];
    
    return result;
}

@end


@implementation SVIndexMigrationPolicy

- (NSString *)plugInIdentifierForCollectionIndexBundleIdentifier:(NSString *)identifier;
{
    // Under 2.0 everything except photo grids becomes a general index
    if (![identifier isEqualToString:@"sandvox.PhotoGridIndex"]) identifier = @"sandvox.GeneralIndex";
    return identifier;
}

- (NSData *)extensiblePropertiesDataFromSource:(NSManagedObject *)sInstance plugInIdentifier:(NSString *)identifier;
{
    return [super extensiblePropertiesDataFromSource:sInstance
                                    plugInIdentifier:[self plugInIdentifierForCollectionIndexBundleIdentifier:identifier]];
}

@end



@implementation SVMediaGraphicMigrationPolicy

- (NSString *)externalSourceURLStringFromExtensibleProperties:(NSDictionary *)properties pluginIdentifier:(NSString *)identifier;
{
    NSString *key = ([identifier isEqualToString:@"sandvox.VideoElement"] ? @"remoteURL" : @"externalImageURL");
    NSString *result = [properties objectForKey:key];
    if ([result length] == 0) result = nil; // #120745
    return result;
}

- (NSString *)typeToPublishForMediaContainerIdentifier:(NSString *)identifier manager:(SVMigrationManager *)manager;
{
    NSManagedObject *mediaFile = [SVMediaMigrationPolicy sourceMediaFileForContainerIdentifier:identifier manager:manager error:NULL];
    NSString *result = [mediaFile valueForKey:@"fileType"];
    
    if (![result isEqualToString:(NSString *)kUTTypePNG] && ![result isEqualToString:(NSString *)kUTTypeGIF])
    {
        result = (NSString *)kUTTypeJPEG;
    }
    
    return result;
}

- (NSData *)extensiblePropertiesDataFromSource:(NSManagedObject *)sInstance plugInIdentifier:(NSString *)identifier;
{
    NSData *result = [super extensiblePropertiesDataFromSource:sInstance plugInIdentifier:identifier];
    
    // Add in link if needed
    NSDictionary *properties = [KSExtensibleManagedObject unarchiveExtensibleProperties:
                                [sInstance valueForKey:@"extensiblePropertiesData"]];
    
    NSMutableDictionary *properties2 = [[KSExtensibleManagedObject unarchiveExtensibleProperties:result] mutableCopy];
    
    if ([[properties objectForKey:@"shouldIncludeLink"] boolValue])
    {
        if ([[properties objectForKey:@"linkImageToOriginal"] boolValue])
        {
            SVLink *link = [[SVLink alloc] initLinkToFullSizeImageOpensInNewWindow:NO];
            [properties2 setObject:[NSKeyedArchiver archivedDataWithRootObject:link] forKey:@"link"];
            [link release];
        }
        else
        {
            NSString *urlString = [properties objectForKey:@"externalURL"];
            if (urlString)
            {
                SVLink *link = [SVLink linkWithURLString:urlString openInNewWindow:NO];
                [properties2 setObject:[NSKeyedArchiver archivedDataWithRootObject:link] forKey:@"link"];
            }
        }
    }
    
    
    result = [KSExtensibleManagedObject archiveExtensibleProperties:properties2];
    [properties2 release];
    return result;
}

@end

