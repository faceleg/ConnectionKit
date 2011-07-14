//
//  SVPagelet.h
//  Sandvox
//
//  Created by Mike on 14/07/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVGraphic.h"


@interface SVPagelet : NSObject <SVGraphicContainer>
{
  @private
    SVGraphic   *_graphic;
}

- (id)initWithGraphic:(SVGraphic *)graphic;

@end
