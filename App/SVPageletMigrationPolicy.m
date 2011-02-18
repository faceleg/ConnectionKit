//
//  SVPageletMigrationPolicy.m
//  Sandvox
//
//  Created by Mike on 15/02/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVPageletMigrationPolicy.h"

#import "SVGraphicFactory.h"


@implementation SVPageletMigrationPolicy

- (BOOL) createDestinationInstancesForSourceInstance:(NSManagedObject *)sInstance entityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError **)error;
{
    @try
    {
        return [super createDestinationInstancesForSourceInstance:sInstance entityMapping:mapping manager:manager error:error];
    }
    @catch (NSException *exception)
    {
        if (error)
        {
            NSString *description = [NSString stringWithFormat:NSLocalizedString(@"%@ plug-in threw an exception while migrating", "migration error"), [sInstance valueForKey:@"pluginIdentifier"]]
            ;
            *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                         code:NSEntityMigrationPolicyError
                         localizedDescription:description];
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
    
    
    NSManagedObject *sPagelet = [[manager sourceInstancesForEntityMappingNamed:[mapping name] destinationInstances:[NSArray arrayWithObject:dInstance]] lastObject]; 
    
    // Only interested in sidebar pagelets
    if ([dInstance valueForKey:@"textAttachment"]) return YES;
    if ([[sPagelet valueForKey:@"location"] intValue] != 1) return YES;
    
    
    // Locate corresponding sidebar object and add pagelet to it
    NSManagedObject *sPage = [sPagelet valueForKey:@"page"];
    NSArray *dSidebars = [manager destinationInstancesForEntityMappingNamed:@"PageToSidebar" sourceInstances:[NSArray arrayWithObject:sPage]];
    
    [[dInstance mutableSetValueForKey:@"sidebars"] addObjectsFromArray:dSidebars];
    
    
    // Carry on down the tree?
    if ([[sPagelet valueForKey:@"shouldPropagate"] boolValue])
    {
        [self propagateSidebarRelationshipForDestinationPagelet:dInstance toDescendantsOfPage:sPage manager:manager];
    }
    
    return YES;
}

- (NSString *)plugInIdentifierFromIdentifier:(NSString *)identifier;
{
    // Convert RSS to Digg. #82975
    if ([identifier isEqualToString:@"sandvox.DiggElement"]) identifier = @"sandvox.FeedElement";
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
    SVPlugIn *plugIn = [[[factory plugInClass] alloc] init];
    
    
    // Grab all reasonable attributes of source
    NSArray *attributes = [[[sInstance entity] attributesByName] allKeys];
    NSMutableDictionary *properties = [[sInstance dictionaryWithValuesForKeys:attributes] mutableCopy];
    
    [properties addEntriesFromDictionary:[KSExtensibleManagedObject unarchiveExtensibleProperties:
                                          [sInstance valueForKey:@"extensiblePropertiesData"]]];
    
    [plugIn awakeFromSourceProperties:properties];
    [properties release];
    
    
    // Serialize the plug-in
    NSMutableDictionary *serializedProperties = [[NSMutableDictionary alloc] init];
    for (NSString *aKey in [[plugIn class] plugInKeys])
    {
        id value = [plugIn serializedValueForKey:aKey];
        if (value) [serializedProperties setObject:value forKey:aKey];
    }
    
    NSData *result = [KSExtensibleManagedObject archiveExtensibleProperties:serializedProperties];
    [serializedProperties release];
    
    return result;
}

- (NSString *)plugInIdentifierForCollectionIndexBundleIdentifier:(NSString *)identifier;
{
    // Under 2.0 everything except photo grids becomes a general index
    if (![identifier isEqualToString:@"sandvox.PhotoGridIndex"]) identifier = @"sandvox.GeneralIndex";
    return identifier;
}

@end
