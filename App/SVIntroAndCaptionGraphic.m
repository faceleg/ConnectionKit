// 
//  SVIntroAndCaptionGraphic.m
//  Sandvox
//
//  Created by Mike on 04/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVIntroAndCaptionGraphic.h"

#import "SVAuxilaryPageletText.h"
#import "SVTitleBox.h"


@implementation SVIntroAndCaptionGraphic 

- (void)awakeFromInsert;
{
    [super awakeFromInsert];
    
    [self createDefaultIntroAndCaption];
}

- (void)createDefaultIntroAndCaption;
{
    SVAuxilaryPageletText *text = [NSEntityDescription
                                   insertNewObjectForEntityForName:@"PageletIntroduction"
                                   inManagedObjectContext:[self managedObjectContext]];
    [self setIntroduction:text];
    
    text = [NSEntityDescription insertNewObjectForEntityForName:@"PageletCaption"
                                         inManagedObjectContext:[self managedObjectContext]];
    [self setCaption:text];
}

@dynamic caption;
@dynamic introduction;

#pragma mark SVPlugInContainer

@dynamic title;
@dynamic showsTitle;
@dynamic bordered;

- (BOOL)showsIntroduction { return ![[[self introduction] hidden] boolValue]; }
- (void)setShowsIntroduction:(BOOL)show { [[self introduction] setHidden:[NSNumber numberWithBool:!show]]; }

- (BOOL)showsCaption { return ![[[self caption] hidden] boolValue]; }
- (void)setShowsCaption:(BOOL)show { [[self caption] setHidden:[NSNumber numberWithBool:!show]]; }

@end
