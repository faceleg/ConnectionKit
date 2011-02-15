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
    NSManagedObject *article = [SVArticle insertPageBodyIntoManagedObjectContext:[manager destinationContext]];
    
    NSDictionary *properties = [KSExtensibleManagedObject unarchiveExtensibleProperties:[sInstance valueForKey:@"extensiblePropertiesData"]];
    
    NSString *html = [properties objectForKey:@"richTextHTML"];
    if (![html length]) html = @"<p>Non-text pages</p>";
    [article setValue:html forKey:@"string"];
    
    [manager associateSourceInstance:sInstance withDestinationInstance:article forEntityMapping:mapping];
     
    return YES;
}

@end
