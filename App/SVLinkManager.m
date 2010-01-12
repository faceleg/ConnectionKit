//
//  SVLinkManager.m
//  Sandvox
//
//  Created by Mike on 12/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVLinkManager.h"


@interface SVLinkManager ()
@property(nonatomic, retain, readwrite) SVUnmodeledLink *selectedLink;
@property(nonatomic, readwrite, getter=isEditable) BOOL editable;
@end


@implementation SVLinkManager

#pragma mark Shared Manager

+ (SVLinkManager *)sharedLinkManager
{
    static SVLinkManager *result;
    if (!result) result = [[SVLinkManager alloc] init];
    return result;
}

#pragma mark Dealloc

- (void)dealloc
{
    [_selectedLink release];
    [super dealloc];
}

#pragma mark Selected Link

- (void)setSelectedLink:(SVUnmodeledLink *)link editable:(BOOL)editable;
{
    [self setSelectedLink:link];
    [self setEditable:editable];
}

@synthesize selectedLink = _selectedLink;
@synthesize editable = _editable;

@end
