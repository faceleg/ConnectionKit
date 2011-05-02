//
//  MapPlugIn.h
//  MapElement
//
//  Created by Terrence Talbot on 2/12/11.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import <Sandvox.h>


@interface MapPlugIn : SVPlugIn
{
    NSArray *_locations;
    NSUInteger _type;
    NSUInteger _zoom;
    BOOL _clickable;
    BOOL _tooltip;
}

// array of dictionaries, keys are location, title, details
@property (nonatomic, retain) NSArray *locations;

// options
@property (nonatomic) NSUInteger type;
@property (nonatomic) NSUInteger zoom;
@property (nonatomic) BOOL clickable;
@property (nonatomic) BOOL tooltip;

@end
