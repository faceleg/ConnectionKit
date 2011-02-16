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
    
    return YES;
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
