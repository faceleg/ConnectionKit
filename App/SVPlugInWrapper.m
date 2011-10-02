//
//  SVPlugInWrapper.m
//  Sandvox
//
//  Created by Mike on 12/09/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVPlugInWrapper.h"


@implementation SVPlugInWrapper

- (id)initWithBundle:(NSBundle *)bundle variation:(NSUInteger)variationIndex;
{
    self = [super initWithBundle:bundle variation:variationIndex];
    
    // Register alternate IDs too, but not for variations, as design takes care of that
    if (variationIndex == NSNotFound)
    {
        for (NSString *anID in [bundle objectForInfoDictionaryKey:@"SVAlternateIdentifiers"])
        {
            [[self class] registerPlugin:self forIdentifier:anID];
        }
    }
    
    return self;
}

@end
