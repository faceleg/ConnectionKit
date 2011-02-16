//
//  SVArticleMigrationPolicy.m
//  Sandvox
//
//  Created by Mike on 15/02/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVArticleMigrationPolicy.h"

#import "SVArticle.h"
#import "KSExtensibleManagedObject.h"


@implementation SVArticleMigrationPolicy

- (BOOL)createDestinationInstancesForSourceInstance:(NSManagedObject *)sInstance entityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError **)error;
{
    // Loate HTML
    NSString *keyPath = [[mapping userInfo] objectForKey:@"stringKeyPath"];
    NSString *string;
    
    if ([[[sInstance entity] attributesByName] objectForKey:keyPath])
    {
        string = [sInstance valueForKey:keyPath];
    }
    else
    {
        NSDictionary *properties = [KSExtensibleManagedObject unarchiveExtensibleProperties:[sInstance valueForKey:@"extensiblePropertiesData"]];
        string = [properties valueForKeyPath:keyPath];
    }
    
    
    // Insert new
    NSManagedObject *article = [NSEntityDescription insertNewObjectForEntityForName:[mapping destinationEntityName]
                                                             inManagedObjectContext:[manager destinationContext]];
    
        
    if (![string length]) string = @"<p>Non-text pages</p>";
    [article setValue:string forKey:@"string"];
    
    
    [manager associateSourceInstance:sInstance withDestinationInstance:article forEntityMapping:mapping];
     
    return YES;
}

@end
