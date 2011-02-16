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

- (void)associateSourceInstance:(NSManagedObject *)sInstance withDestinationInstance:(NSManagedObject *)dInstance forEntityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager;
{
    [manager associateSourceInstance:sInstance withDestinationInstance:dInstance forEntityMapping:mapping];
}

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
    
        
    if (![string length])
    {
        if ([keyPath isEqualToString:@"richTextHTML"])
        {
            string = @"<p>Non-text pages</p>";
        }
        else
        {
            string = @"<p></p>";
        }
    }
    [article setValue:string forKey:@"string"];
    
    
    [self associateSourceInstance:sInstance withDestinationInstance:article forEntityMapping:mapping manager:manager];
     
    return YES;
}

@end



@implementation SVAuxiliaryPageletTextMigrationPolicy

- (void)associateSourceInstance:(NSManagedObject *)sInstance withDestinationInstance:(NSManagedObject *)dInstance forEntityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager;
{
    // Also import whether to hide
    BOOL hide = [[dInstance valueForKeyPath:@"string.stringByConvertingHTMLToPlainText"] length] == 0;
    [dInstance setValue:NSBOOL(hide) forKey:@"hidden"];
    
    [super associateSourceInstance:sInstance withDestinationInstance:dInstance forEntityMapping:mapping manager:manager];
}

@end
