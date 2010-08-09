//
//  SVLogoImage.m
//  Sandvox
//
//  Created by Mike on 02/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVLogoImage.h"

#import "SVMediaRecord.h"
#import "KTPage.h"
#import "SVWebEditorHTMLContext.h"

#import "NSManagedObject+KTExtensions.h"


@implementation SVLogoImage

- (void)awakeFromInsert
{
    [super awakeFromInsert];
    
    NSURL *placeholderURL = [NSURL fileURLWithPath:
                             [[NSBundle mainBundle] pathForImageResource:@"LogoPlaceholder"]];
    
    [self setMedia:[SVMediaRecord placeholderMediaWithURL:placeholderURL
                                               entityName:@"LogoMedia"
                           insertIntoManagedObjectContext:[self managedObjectContext]]];
    
    [self makeOriginalSize];
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
- (BOOL)isPlacementEditable; { return NO; }
- (SVTextAttachment *)textAttachment { return nil; }

- (SVLink *)link; { return NSNotApplicableMarker; }

#pragma mark Serialization

- (void)populateSerializedProperties:(NSMutableDictionary *)propertyList;
{
    [super populateSerializedProperties:propertyList];
    
    // Correct entity to Image
    [propertyList setObject:@"Image" forKey:@"entity"];
}

@end
