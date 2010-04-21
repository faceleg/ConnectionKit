//
//  SVIntroAndCaptionGraphic.h
//  Sandvox
//
//  Created by Mike on 04/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVGraphic.h"


@class SVAuxiliaryPageletText;


@interface SVIntroAndCaptionGraphic : SVGraphic <SVPageletPlugInContainer>

- (void)createDefaultIntroAndCaption;

@property (nonatomic, retain) SVAuxiliaryPageletText *caption;
@property (nonatomic, retain) SVAuxiliaryPageletText *introduction;

@end



