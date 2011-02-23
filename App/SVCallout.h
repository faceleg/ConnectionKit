//
//  SVCallout.h
//  Sandvox
//
//  Created by Mike on 23/02/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SVGraphicContainer.h"


@interface SVCallout : NSObject <SVGraphicContainer>
- (void)write:(SVHTMLContext *)context pagelets:(NSArray *)pagelets;
@end
