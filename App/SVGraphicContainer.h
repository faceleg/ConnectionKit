//
//  SVComponent.h
//  Sandvox
//
//  Created by Mike on 23/02/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVComponent.h"


@protocol SVGraphic;


@interface SVInlineGraphicContainer : NSObject <SVComponent>
{
  @private
    id <SVGraphic>  _graphic;
}

- (id)initWithGraphic:(id <SVGraphic>)graphic;
@property(nonatomic, retain, readonly) id <SVGraphic> graphic;

@end

