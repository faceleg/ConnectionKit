// 
//  SVIntroAndCaptionGraphic.m
//  Sandvox
//
//  Created by Mike on 04/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVIntroAndCaptionGraphic.h"

#import "SVAuxiliaryPageletText.h"
#import "SVTitleBox.h"

#import "NSError+Karelia.h"


@implementation SVIntroAndCaptionGraphic 

- (void)awakeFromInsert;
{
    [super awakeFromInsert];
    
    [self createDefaultIntroAndCaption];
}

- (void)createDefaultIntroAndCaption;
{
    SVAuxiliaryPageletText *text = [NSEntityDescription
                                   insertNewObjectForEntityForName:@"PageletIntroduction"
                                   inManagedObjectContext:[self managedObjectContext]];
    [self setIntroduction:text];
    
    text = [NSEntityDescription insertNewObjectForEntityForName:@"PageletCaption"
                                         inManagedObjectContext:[self managedObjectContext]];
    [self setCaption:text];
}

@dynamic caption;
@dynamic introduction;

- (BOOL)validateForInlinePlacement:(NSError **)error;
{
    BOOL result = [super validateForInlinePlacement:error];
    
    if (!(result = ![self showsIntroduction]))
    {
        if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                                code:NSManagedObjectValidationError
                                localizedDescription:@"Graphics cannot show introduction while inline"];
    }
    else if (!(result = ![self showsCaption]))
    {
        *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                     code:NSManagedObjectValidationError
                     localizedDescription:@"Graphics cannot show caption while inline"];
    }
    
    return result;
}

#pragma mark SVPlugInContainer

@dynamic title;
@dynamic showsTitle;
@dynamic bordered;

- (BOOL)showsIntroduction { return ![[[self introduction] hidden] boolValue]; }
- (void)setShowsIntroduction:(BOOL)show { [[self introduction] setHidden:[NSNumber numberWithBool:!show]]; }

- (BOOL)showsCaption { return ![[[self caption] hidden] boolValue]; }
- (void)setShowsCaption:(BOOL)show { [[self caption] setHidden:[NSNumber numberWithBool:!show]]; }

@end
