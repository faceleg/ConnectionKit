//
//  NSHelpManager+KTExtensions.h
//  KTComponents
//
//  Created by Dan Wood on 4/11/07.
//  Copyright (c) 2007-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSHelpManager ( KTExtensions )

+(BOOL)gotoHelpAnchor:(NSString *)anAnchor;	// may include # for section within a page

@end
