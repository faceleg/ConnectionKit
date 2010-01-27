// 
//  SVGraphic.m
//  Sandvox
//
//  Created by Mike on 11/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVGraphic.h"

#import "SVHTMLTemplateParser.h"
#import "SVBody.h"

#import "NSManagedObject+KTExtensions.h"
#import "NSString+Karelia.h"


@implementation SVGraphic

#pragma mark HTML

@dynamic elementID;
- (BOOL) shouldPublishEditingElementID { return YES; }

@end
