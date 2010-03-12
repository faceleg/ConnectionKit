//
//  SVPageProtocol.h
//  Sandvox
//
//  Created by Mike on 02/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SVPageletPlugIn.h"


@protocol SVPage <NSObject>

- (NSString *)identifier;

- (NSString *)title;
- (NSString *)titleHTMLString;

- (NSString *)language;

@end


@interface SVPageletPlugIn (SVPage)
- (id <SVPage>)pageWithIdentifier:(NSString *)identifier;
@end


// Posted when the page is to be deleted. Notification object is the page itself.
extern NSString *SVPageWillBeDeletedNotification;