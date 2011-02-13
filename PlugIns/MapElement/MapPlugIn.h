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
    NSString *_location;
    NSString *_locationTitle;
    NSUInteger _type;
    NSUInteger _zoom;
    BOOL _clickable;
    BOOL _tooltip;
}

@property (nonatomic, copy) NSString *location;
@property (nonatomic, copy) NSString *locationTitle;
@property (nonatomic) NSUInteger type;
@property (nonatomic) NSUInteger zoom;
@property (nonatomic) BOOL clickable;
@property (nonatomic) BOOL tooltip;

@end
