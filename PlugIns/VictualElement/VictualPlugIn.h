//
//  VictualPlugIn.h
//  VictualElement
//
//  Created by Terrence Talbot on 1/5/11.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import <Sandvox.h>


@interface VictualPlugIn : SVPlugIn
{
    NSURL       *_feedURL;
    NSUInteger  _limit;
}

@property(nonatomic, copy) NSURL *feedURL;
@property(nonatomic) NSUInteger limit;

@end
