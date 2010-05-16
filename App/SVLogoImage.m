//
//  SVLogoImage.m
//  Sandvox
//
//  Created by Mike on 02/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVLogoImage.h"

#import "NSManagedObject+KTExtensions.h"


@implementation SVLogoImage

- (void)awakeFromInsert
{
    [super awakeFromInsert];
    
    [self setPrimitiveValue:[NSNumber numberWithUnsignedInt:200] forKey:@"width"];
    [self setPrimitiveValue:[NSNumber numberWithUnsignedInt:128] forKey:@"height"];
}

- (void)createDefaultIntroAndCaption; { }

@dynamic hidden;

- (SVTitleBox *)titleBox { return nil; }
- (void)setTitle:(NSString *)title; { }
- (SVAuxiliaryPageletText *)introduction { return nil; }
- (void)setIntroduction:(SVAuxiliaryPageletText *)caption { }
- (SVAuxiliaryPageletText *)caption { return nil; }
- (void)setCaption:(SVAuxiliaryPageletText *)caption { }

- (NSNumber *)placement { return nil; }
- (SVTextAttachment *)textAttachment { return nil; }

- (BOOL)isPagelet { return NO; }

- (NSURL *)placeholderImageURL; // the fallback when no media or external source is chose
{
    NSURL *result = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForImageResource:@"LogoPlaceholder"]];
    return result;
}

#pragma mark Serialization

- (void)populateSerializedProperties:(NSMutableDictionary *)propertyList;
{
    [super populateSerializedProperties:propertyList];
    
    // Correct entity to Image
    [propertyList setObject:@"Image" forKey:@"entity"];
}

@end
