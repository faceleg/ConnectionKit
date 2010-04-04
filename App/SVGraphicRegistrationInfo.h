//
//  SVGraphicRegistrationInfo.h
//  Sandvox
//
//  Created by Mike on 04/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SVGraphicRegistrationInfo : NSObject
{
  @private
    Class   _pageletClass;
    NSImage *_icon;
}

- (id)initWithPageletClass:(Class)pageletClass icon:(NSImage *)icon;

@property(nonatomic, readonly) Class pageletClass;
@property(nonatomic, readonly) NSImage *icon;

@end
