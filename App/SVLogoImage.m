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


@interface SVMediaGraphic (SVLogoImage)
- (void)setSourceWithMediaRecord:(SVMediaRecord *)media;
@end


#pragma mark -


@implementation SVLogoImage

- (void)awakeFromInsert
{
    [super awakeFromInsert];
    
    NSURL *placeholderURL = [NSURL fileURLWithPath:
                             [[NSBundle mainBundle] pathForImageResource:@"LogoPlaceholder"]];
    
    [self setSourceWithMediaRecord:[SVMediaRecord mediaWithBundledURL:placeholderURL
                                                           entityName:[[self class] mediaEntityName]
                                       insertIntoManagedObjectContext:[self managedObjectContext]]];
    
    [[self plugIn] setWidth:200];
    [[self plugIn] setHeight:128];
    [self makeOriginalSize];
    [self setTypeToPublish:[[self media] typeOfFile]];
}

- (SVMediaRecord *)posterFrame; { return nil; }
- (void)setPosterFrame:(SVMediaRecord *)media; { }

- (void)createDefaultIntroAndCaption; { }

+ (NSString *)mediaEntityName; { return @"LogoMedia"; }

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
