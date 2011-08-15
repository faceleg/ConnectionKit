//
//  SVCallout.h
//  Sandvox
//
//  Created by Mike on 23/02/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SVComponent.h"


@interface SVCallout : NSObject <SVComponent>
- (void)write:(SVHTMLContext *)context pagelets:(NSArray *)pagelets;
@end
