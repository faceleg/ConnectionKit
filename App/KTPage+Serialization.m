//
//  KTPage+Serialization.m
//  Sandvox
//
//  Created by Mike on 16/01/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//


#import "KTPage.h"

#import "SVArticle.h"
#import "SVAttributedHTML.h"
#import "SVTitleBox.h"


static NSMutableDictionary *sDeserializingPages;


@implementation KTPage (Serialization)

- (void)populateSerializedProperties:(NSMutableDictionary *)propertyList
{
    [super populateSerializedProperties:propertyList];
    
    // Title
    [propertyList setValue:[[self titleBox] textHTMLString]
                    forKey:@"titleHTMLString"];
    
    // Body
    NSData *article = [[[self article] attributedHTMLString] serializedProperties];
    [propertyList setValue:article forKey:@"article"];
    
    // Code Injection
    [propertyList setValue:[[self codeInjection] serializedProperties]
                    forKey:@"codeInjection"];
    
    // Children, but not if root. #89388
    if (![self isRootPage])
    {
        NSArray *children = [[self sortedChildren] valueForKey:@"serializedProperties"];
        [propertyList setValue:children forKey:@"childItems"];
    }
}

- (void)awakeFromPropertyList:(id)propertyList
{
    [super awakeFromPropertyList:propertyList];
    
    
    // Title
    [[self titleBox] setTextHTMLString:[propertyList objectForKey:@"titleHTMLString"]];
    
    
    // Code Injection
    [[self codeInjection] awakeFromPropertyList:[propertyList objectForKey:@"codeInjection"]];
    
    
    // Children
    NSManagedObjectContext *context = [self managedObjectContext];
    NSMutableSet *childItems = [self mutableSetValueForKey:@"childItems"];
    
    NSArray *children = [propertyList objectForKey:@"childItems"];
    for (id aChild in children)
    {
        SVSiteItem *duplicate = [[NSManagedObject alloc] initWithEntity:[self entity]
                                         insertIntoManagedObjectContext:context];
        [duplicate awakeFromPropertyList:aChild parentItem:self];
        [childItems addObject:duplicate];
    }
    
    
    // Text
    NSData *article = [propertyList objectForKey:@"article"];
    if (article)
    {
        NSAttributedString *html = [NSAttributedString attributedHTMLStringWithPropertyList:article
                                                  insertAttachmentsIntoManagedObjectContext:context];
        [[self article] setAttributedHTMLString:html];
    }
}

- (void)awakeFromPropertyList:(id)propertyList parentItem:(SVSiteItem *)parent;
{
    [self setMaster:[parent master]];
    
    // If this is the root page to be deserialized temporarily use a global variable (yeah I know, weak design), to record old page identifiers. #102564
    if (!sDeserializingPages)
    {
        sDeserializingPages = [[NSMutableDictionary alloc] init];
        @try
        {
            [super awakeFromPropertyList:propertyList parentItem:parent];
        }
        @finally
        {
            [sDeserializingPages release]; sDeserializingPages = nil;
        }
    }
    else
    {
        [super awakeFromPropertyList:propertyList parentItem:parent];
    }
}

- (void)setSerializedValue:(id)serializedValue forKey:(NSString *)key
{
    // Several properties are not applicable for applying to a new page, so ignore them
    static NSSet *sIgnoredKeys;
    if (!sIgnoredKeys)
    {
        sIgnoredKeys = [[NSSet alloc] initWithObjects:
                        @"fileName",
                        @"shouldUpdateFileNameWhenTitleChanges",
                        @"datePublished",
                        nil];
    }
    
    if (![sIgnoredKeys containsObject:key])
    {
        if ([key isEqualToString:@"uniqueID"])
        {
            // Temporarily record that serialized copy of this page had that ID. #102564
            [sDeserializingPages setObject:self forKey:serializedValue];
        }
        
        [super setSerializedValue:serializedValue forKey:key];
    }
}

+ (KTPage *)deserializingPageForIdentifier:(NSString *)identifier;
{
    return [sDeserializingPages objectForKey:identifier];
}

@end
