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
}

- (void)awakeFromPropertyList:(id)propertyList
{
    [super awakeFromPropertyList:propertyList];
    
    // Title
    [[self titleBox] setTextHTMLString:[propertyList objectForKey:@"titleHTMLString"]];
}

- (void)setSerializedValue:(id)serializedValue forKey:(NSString *)key
{
    // Want a fresh ID
    if (![key isEqualToString:@"uniqueID"])
    {
        [super setSerializedValue:serializedValue forKey:key];
    }
}

@end
