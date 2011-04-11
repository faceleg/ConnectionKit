//
//  DiggPlugIn.h
//  DiggElement
//
//  Created by Terrence Talbot on 4/9/11.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "Sandvox.h"


@interface DiggPlugIn : SVPlugIn
{
    BOOL _diggCount;
    BOOL _diggDescriptions;
    BOOL _openLinksInNewWindow;
    
    NSUInteger _diggStoryPromotion;
    NSUInteger _diggType;
    NSUInteger _diggUserOptions;
    NSUInteger _maximumStories;
    
    NSString *_diggCategory;
    NSString *_diggCategoryString;
    NSString *_diggStoryPromotionString;
    NSString *_diggUser;
    NSString *_diggUserOptionString;
}

@property (nonatomic) BOOL diggCount;
@property (nonatomic) BOOL diggDescriptions;
@property (nonatomic) BOOL openLinksInNewWindow;

@property (nonatomic) NSUInteger diggStoryPromotion;
@property (nonatomic) NSUInteger diggType;
@property (nonatomic) NSUInteger diggUserOptions;
@property (nonatomic) NSUInteger maximumStories;

@property (nonatomic, copy) NSString *diggCategory;
@property (nonatomic, copy) NSString *diggCategoryString;
@property (nonatomic, copy) NSString *diggStoryPromotionString;
@property (nonatomic, copy) NSString *diggUser;
@property (nonatomic, copy) NSString *diggUserOptionString;

@end
