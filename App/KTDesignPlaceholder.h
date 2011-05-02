//
//  KTDesignPlaceholder.h
//  Marvel
//
//  Created by Mike on 30/05/2008.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//
//
//  This is a special class of object that the master creates in the event that it cannot locate the
//  proper KTDesign object.


#import <Cocoa/Cocoa.h>
#import "KTDesign.h"


@interface KTDesignPlaceholder : KTDesign
{
    NSString *myBundleIdentifier;
}

- (id)initWithBundleIdentifier:(NSString *)identifier;

@end
