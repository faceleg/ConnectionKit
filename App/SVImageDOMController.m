//
//  SVImageDOMController.m
//  Sandvox
//
//  Created by Mike on 27/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVImageDOMController.h"


static NSString *sImageSizeObservationContext = @"SVImageSizeObservation";


@implementation SVImageDOMController

- (void)dealloc
{
    [self setRepresentedObject:nil];
    [super dealloc];
}

- (void)setRepresentedObject:(id)image
{
    [[self representedObject] removeObserver:self forKeyPath:@"width"];
    [[self representedObject] removeObserver:self forKeyPath:@"height"];
    
    [super setRepresentedObject:image];
    
    [image addObserver:self forKeyPath:@"width" options:0 context:sImageSizeObservationContext];
    [image addObserver:self forKeyPath:@"height" options:0 context:sImageSizeObservationContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context == sImageSizeObservationContext)
    {
        [[self HTMLElement] setAttribute:keyPath
                                   value:[[object valueForKeyPath:keyPath] description]];
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}


@end
