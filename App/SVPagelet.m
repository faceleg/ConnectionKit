//
//  SVPagelet.m
//  Sandvox
//
//  Created by Mike on 14/07/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVPagelet.h"

#import "SVGraphicContainerDOMController.h"
#import "KTPage.h"


@implementation SVPagelet

- (id)initWithGraphic:(SVGraphic *)graphic;
{
    if (self = [self init])
    {
        _graphic = [graphic retain];
    }
    return self;
}

- (void)dealloc;
{
    [_graphic release];
    [super dealloc];
}

- (SVDOMController *)newDOMControllerWithElementIdName:(NSString *)elementID node:(DOMNode *)node;
{
    SVDOMController *result = [[SVGraphicContainerDOMController alloc] initWithElementIdName:elementID node:node];
    [result setRepresentedObject:self];
    return result;
}

- (CGFloat)maxWidthOnPage:(KTPage *)page;
{
    return [_graphic maxWidthOnPage:page];
}

#pragma mark Equality

- (BOOL)isEqual:(id)object;
{
    if (self == object) return YES;
    if (![object isKindOfClass:[SVPagelet class]]) return NO;
    return [_graphic isEqual:((SVPagelet *)object)->_graphic];
}

- (int)hash;
{
    return [_graphic hash];
}

@end
