//
//  SVGraphicRegistrationInfo.m
//  Sandvox
//
//  Created by Mike on 04/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVGraphicRegistrationInfo.h"


@implementation SVGraphicRegistrationInfo

- (id)initWithPageletClass:(Class)pageletClass icon:(NSImage *)icon;
{
    OBPRECONDITION(pageletClass);
    OBPRECONDITION(icon);
    
    [self init];
    
    _pageletClass = [pageletClass retain];
    _icon = [icon retain];
    
    return self;
}

- (void)dealloc
{
    [_pageletClass release];
    [_icon release];
    
    [super dealloc];
}

@synthesize pageletClass = _pageletClass;
@synthesize icon = _icon;

@end

