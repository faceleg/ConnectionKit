// 
//  SVIntroAndCaptionGraphic.m
//  Sandvox
//
//  Created by Mike on 04/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVIntroAndCaptionGraphic.h"

#import "SVBody.h"


@implementation SVIntroAndCaptionGraphic 

- (void)awakeFromInsert;
{
    [super awakeFromInsert];
    
    [self createDefaultIntroAndCaption];
}

- (void)createDefaultIntroAndCaption;
{
    SVBody *text = [NSEntityDescription insertNewObjectForEntityForName:@"PageletIntroduction"
                                                 inManagedObjectContext:[self managedObjectContext]];
    [text setString:@""];
    [self setIntroduction:text];
    
    text = [NSEntityDescription insertNewObjectForEntityForName:@"PageletCaption"
                                         inManagedObjectContext:[self managedObjectContext]];
    [text setString:@""];
    [self setCaption:text];
}

@dynamic caption;
@dynamic introduction;

@end
