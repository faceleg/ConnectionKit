//
//  SVTextMigrationPolicy.m
//  Sandvox
//
//  Created by Mike on 15/02/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVTextMigrationPolicy.h"

#import "SVArticle.h"
#import "KSExtensibleManagedObject.h"
#import "SVGraphicFactory.h"

#import "NSSet+Karelia.h"
#import "NSString+Karelia.h"

#import "KSStringHTMLEntityUnescaping.h"
#import "KSStringXMLEntityEscaping.h"


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
            string = @"";
        }
        else
        {
            string = @"<p><br /></p>";
        }
    }
    [article setValue:string forKey:@"string"];
    
    
    [self associateSourceInstance:sInstance withDestinationInstance:article forEntityMapping:mapping manager:manager];
     
    return YES;
}

- (BOOL)createRelationshipsForDestinationInstance:(NSManagedObject *)dInstance entityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError **)error;
{
    if (![super createRelationshipsForDestinationInstance:dInstance entityMapping:mapping manager:manager error:error]) return NO;
    
    
    // Fully hook up attachments
    NSArray *attachments = [[dInstance valueForKey:@"attachments"] KS_sortedArrayUsingDescriptors:[SVRichText attachmentSortDescriptors]];
    NSUInteger i, count = [attachments count];
    
    for (i = 0; i < count; i++)
    {
        NSManagedObject *anAttachment = [attachments objectAtIndex:i];
        //OBASSERT([[anAttachment valueForKey:@"placement"] intValue] == SVGraphicPlacementCallout);
        
        // Correct location in case source document was a little wonky
        
        NSString *string = [[NSString stringWithUnichar:NSAttachmentCharacter] stringByAppendingString:[dInstance valueForKey:@"string"]];
        [dInstance setValue:string forKey:@"string"];
        
        [anAttachment setValue:[NSNumber numberWithUnsignedInteger:i] forKey:@"location"];
    }
    
    
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


@implementation SVTitleMigrationPolicy

- (BOOL)createDestinationInstancesForSourceInstance:(NSManagedObject *)sInstance entityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError **)error;
{
    NSManagedObject *dInstance = [NSEntityDescription insertNewObjectForEntityForName:[mapping destinationEntityName]
                                                               inManagedObjectContext:[manager destinationContext]];
    
    NSString *html = [sInstance valueForKey:@"titleHTML"];
    BOOL hidden = NO;
    
    if (![[html stringByConvertingHTMLToPlainText] length])
    {
        // There was no visible text, so user deleted it in 1.x. Reset to a default title, and make hidden
        hidden = YES;
        
        NSString *identifier = [sInstance valueForKey:@"pluginIdentifier"];
        SVGraphicFactory *factory = [SVGraphicFactory factoryWithIdentifier:identifier];
        html = [[factory name] stringByEscapingHTMLEntities];
        
        if (!html) html = @"Untitled";
    }
    
    [dInstance setValue:NSBOOL(hidden) forKey:@"hidden"];
    [dInstance setValue:html forKey:@"textHTMLString"];
    
    [manager associateSourceInstance:sInstance withDestinationInstance:dInstance forEntityMapping:mapping];
    
    return YES;
}

@end
