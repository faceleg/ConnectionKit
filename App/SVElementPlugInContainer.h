//
//  SVElementPlugInContainer.h
//  Sandvox
//
//  Created by Mike on 29/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@protocol SVElementPlugInContainer <NSObject>

#pragma mark Site
- (NSString *)siteObjectIDURIRepresentationString;  // unique per site. used by Badge plug-in
- (NSString *)languageCode;	// used by ContactElementDelegate

@end
