//
//  SVPageletMigrationPolicy.m
//  Sandvox
//
//  Created by Mike on 15/02/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVPageletMigrationPolicy.h"

#import "SVGraphicFactory.h"

#import "KSStringHTMLEntityUnescaping.h"
#import "KSStringXMLEntityEscaping.h"


@implementation SVPageletMigrationPolicy

- (void) propagateSidebarRelationshipForDestinationPagelet:(NSManagedObject *)dInstance toDescendantsOfPage:(NSManagedObject *)sPage manager:(NSMigrationManager *)manager
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

@end


@implementation SVPageletTitleMigrationPolicy

- (BOOL)createDestinationInstancesForSourceInstance:(NSManagedObject *)sInstance entityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError **)error;
{
    NSManagedObject *dInstance = [NSEntityDescription insertNewObjectForEntityForName:@"PageletTitle" inManagedObjectContext:[manager destinationContext]];
    
    NSString *html = [sInstance valueForKey:@"titleHTML"];
    BOOL hidden = NO;
    
    if (![[html stringByConvertingHTMLToPlainText] length])
    {
        // There was no visible text, so user deleted it in 1.x. Reset to a default title, and make hidden
        hidden = YES;
        
        NSString *identifier = [sInstance valueForKey:@"pluginIdentifier"];
        SVGraphicFactory *factory = [SVGraphicFactory factoryWithIdentifier:identifier];
        html = [[factory name] stringByEscapingHTMLEntities];
        
        if (!html) html = @"Pagelet";
    }
    
    [dInstance setValue:NSBOOL(hidden) forKey:@"hidden"];
    [dInstance setValue:html forKey:@"textHTMLString"];

    [manager associateSourceInstance:sInstance withDestinationInstance:dInstance forEntityMapping:mapping];
    
    return YES;
}

@end
