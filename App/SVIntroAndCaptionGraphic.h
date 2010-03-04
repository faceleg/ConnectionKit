//
//  SVIntroAndCaptionGraphic.h
//  Sandvox
//
//  Created by Mike on 04/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVGraphic.h"


@class SVBody;


@interface SVIntroAndCaptionGraphic : SVGraphic  

- (void)createDefaultIntroAndCaption;

@property (nonatomic, retain) SVBody *caption;
@property (nonatomic, retain) SVBody *introduction;

@end



