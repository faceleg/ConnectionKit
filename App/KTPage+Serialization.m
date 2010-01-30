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

- (void)populateSerializedValues:(NSMutableDictionary *)propertyList
{
    [super populateSerializedValues:propertyList];
    
    // Title
    [propertyList setValue:[[self titleBox] textHTMLString]
                    forKey:@"titleHTMLString"];
    
    // Body
    [propertyList setValue:[[self body] propertyList] forKey:@"body"];
    
    // Code Injection
    [propertyList setValue:[[self codeInjection] propertyList]
                    forKey:@"codeInjection"];
}

- (void)awakeFromPropertyList:(id)propertyList
{
    [super awakeFromPropertyList:propertyList];
    
    // Title
    [[self titleBox] setTextHTMLString:[propertyList objectForKey:@"titleHTMLString"]];
    
    // Code Injection
    [[self codeInjection] awakeFromPropertyList:[propertyList objectForKey:@"codeInjection"]];
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
