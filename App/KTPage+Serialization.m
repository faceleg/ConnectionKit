//
//  KTPage+Serialization.m
//  Sandvox
//
//  Created by Mike on 16/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//


#import "KTPage.h"

#import "SVTitleBox.h"


@implementation KTPage (Serialization)

- (void)populateSerializedProperties:(NSMutableDictionary *)propertyList
{
    [super populateSerializedProperties:propertyList];
    
    // Title
    [propertyList setValue:[[self titleBox] textHTMLString]
                    forKey:@"titleHTMLString"];
    
    // Body
    [propertyList setValue:[[self article] serializedProperties] forKey:@"article"];
    
    // Code Injection
    [propertyList setValue:[[self codeInjection] serializedProperties]
                    forKey:@"codeInjection"];
    
    // Children
    NSArray *children = [[self sortedChildren] valueForKey:@"serializedProperties"];
    [propertyList setValue:children forKey:@"childItems"];
}

- (void)awakeFromPropertyList:(id)propertyList
{
    [super awakeFromPropertyList:propertyList];
    
    // Title
    [[self titleBox] setTextHTMLString:[propertyList objectForKey:@"titleHTMLString"]];
    
    // Code Injection
    [[self codeInjection] awakeFromPropertyList:[propertyList objectForKey:@"codeInjection"]];
    
    // Children
    NSArray *children = [propertyList objectForKey:@"childItems"];
    for (id aChild in children)
    {
        // FIXME: This heavily duplicates codes from -[SVSiteOutlineViewController duplicate:]
        SVSiteItem *duplicate = [[NSManagedObject alloc] initWithEntity:[self entity]
                                         insertIntoManagedObjectContext:[self managedObjectContext]];
        if ([duplicate isKindOfClass:[KTPage class]])
        {
            [(KTPage *)duplicate setMaster:[self master]];
        }
        [duplicate awakeFromPropertyList:aChild];
        [self addChildItem:duplicate];
    }
}

- (void)setSerializedValue:(id)serializedValue forKey:(NSString *)key
{
    // Several properties are not applicable for applying to a new page, so ignore them
    static NSSet *sIgnoredKeys;
    if (!sIgnoredKeys)
    {
        sIgnoredKeys = [[NSSet alloc] initWithObjects:
                        @"uniqueID",
                        @"fileName",
                        @"shouldUpdateFileNameWhenTitleChanges",
                        @"publishedPath",
                        nil];
    }
    
    if (![sIgnoredKeys containsObject:key])
    {
        [super setSerializedValue:serializedValue forKey:key];
    }
}

@end
