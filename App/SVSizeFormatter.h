//
//  SVSizeFormatter.h
//  Sandvox
//
//  Created by Mike on 16/09/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//
//  For the Size fields in Metrics Inspector, need a custom formatter that accepts all values, falling back to nil for everything that would usually be rejected.


#import <Cocoa/Cocoa.h>


@interface SVSizeFormatter : NSNumberFormatter
@end
