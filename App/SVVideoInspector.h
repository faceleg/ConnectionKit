//
//  SVVideoInspector.h
//  Sandvox
//
//  Created by Dan Wood on 8/6/10.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//


#import "SVMediaGraphicInspector.h"


@interface SVVideoInspector : SVMediaGraphicInspector {
    IBOutlet NSImageView    *oPosterImageView;
}

- (IBAction)choosePosterFrame:(id)sender;

@end
